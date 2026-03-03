#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./monitoring/validate-observability.sh \
    --app-url http://APP_IP:5000 \
    --prom-url http://MONITORING_IP:9090 \
    --alert-url http://MONITORING_IP:9093 \
    --jaeger-url http://MONITORING_IP:16686 \
    --loki-url http://MONITORING_IP:3100 \
    [--duration-minutes 12] \
    [--interval-seconds 1] \
    [--delay-ms 450]

The script simulates latency and errors, then validates:
1) RED metrics exceed alert thresholds
2) Alertmanager has active high-error/high-latency alerts
3) Loki logs include trace_id/span_id
4) Jaeger trace is retrievable from a trace_id found in logs
EOF
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
}

trim_trailing_slash() {
  local value="$1"
  echo "${value%/}"
}

prom_query() {
  local base_url="$1"
  local expr="$2"
  curl -sS -G "${base_url}/api/v1/query" --data-urlencode "query=${expr}"
}

main() {
  local app_url=""
  local prom_url=""
  local alert_url=""
  local jaeger_url=""
  local loki_url=""
  local duration_minutes=12
  local interval_seconds=1
  local delay_ms=450

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --app-url)
        app_url="$2"
        shift 2
        ;;
      --prom-url)
        prom_url="$2"
        shift 2
        ;;
      --alert-url)
        alert_url="$2"
        shift 2
        ;;
      --jaeger-url)
        jaeger_url="$2"
        shift 2
        ;;
      --loki-url)
        loki_url="$2"
        shift 2
        ;;
      --duration-minutes)
        duration_minutes="$2"
        shift 2
        ;;
      --interval-seconds)
        interval_seconds="$2"
        shift 2
        ;;
      --delay-ms)
        delay_ms="$2"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done

  if [[ -z "$app_url" || -z "$prom_url" || -z "$alert_url" || -z "$jaeger_url" || -z "$loki_url" ]]; then
    usage
    exit 1
  fi

  require_command curl
  require_command jq

  app_url="$(trim_trailing_slash "$app_url")"
  prom_url="$(trim_trailing_slash "$prom_url")"
  alert_url="$(trim_trailing_slash "$alert_url")"
  jaeger_url="$(trim_trailing_slash "$jaeger_url")"
  loki_url="$(trim_trailing_slash "$loki_url")"

  echo "Validating endpoint reachability..."
  curl -fsS "${app_url}/health" >/dev/null
  curl -fsS "${prom_url}/-/healthy" >/dev/null
  curl -fsS "${alert_url}/-/healthy" >/dev/null
  curl -fsS "${jaeger_url}" >/dev/null
  curl -fsS "${loki_url}/ready" >/dev/null
  echo "Endpoints reachable."

  echo ""
  echo "Generating sustained latency and error traffic for ${duration_minutes} minute(s)..."
  local end_at=$((SECONDS + (duration_minutes * 60)))
  local i=0

  while [[ $SECONDS -lt $end_at ]]; do
    i=$((i + 1))

    curl -sS -m 10 "${app_url}/api/tasks?delay_ms=${delay_ms}" >/dev/null || true

    if (( i % 4 == 0 )); then
      curl -sS -m 10 -X POST "${app_url}/api/tasks" \
        -H 'Content-Type: application/json' \
        -d '{"title":"   "}' >/dev/null || true
    else
      curl -sS -m 10 -X POST "${app_url}/api/tasks" \
        -H 'Content-Type: application/json' \
        -d "{\"title\":\"load-task-${i}\",\"description\":\"observability validation\"}" >/dev/null || true
    fi

    if (( i % 6 == 0 )); then
      curl -sS -m 10 "${app_url}/api/system/overview" >/dev/null || true
    fi

    sleep "$interval_seconds"
  done

  echo "Traffic generation completed."

  echo ""
  echo "Evaluating RED metrics against alert thresholds..."

  local error_rate_expr='100 * sum(rate(taskflow_http_errors_total{route!="/metrics"}[5m])) / clamp_min(sum(rate(taskflow_http_requests_total{route!="/metrics"}[5m])), 0.001)'
  local latency_expr='histogram_quantile(0.95, sum(rate(taskflow_http_request_duration_seconds_bucket{route!="/metrics"}[5m])) by (le)) * 1000'

  local error_rate
  error_rate="$(prom_query "$prom_url" "$error_rate_expr" | jq -r '.data.result[0].value[1] // "0"')"

  local latency_ms
  latency_ms="$(prom_query "$prom_url" "$latency_expr" | jq -r '.data.result[0].value[1] // "0"')"

  echo "Current error rate: ${error_rate}%"
  echo "Current p95 latency: ${latency_ms}ms"

  echo ""
  echo "Checking active alerts..."
  local alerts_json
  alerts_json="$(curl -sS "${alert_url}/api/v2/alerts")"

  local error_alert_count
  error_alert_count="$(echo "$alerts_json" | jq -r '[.[] | select(.status.state == "active" and .labels.alertname == "TaskflowHighErrorRate")] | length')"

  local latency_alert_count
  latency_alert_count="$(echo "$alerts_json" | jq -r '[.[] | select(.status.state == "active" and .labels.alertname == "TaskflowHighLatency")] | length')"

  echo "TaskflowHighErrorRate active alerts: ${error_alert_count}"
  echo "TaskflowHighLatency active alerts: ${latency_alert_count}"

  echo ""
  echo "Checking Loki logs for trace correlation fields..."
  local loki_query='{service="taskflow-backend"} |= "http_request_completed" | json | level=~"warn|error" | trace_id!="" | span_id!=""'
  local loki_json
  loki_json="$(curl -sS -G "${loki_url}/loki/api/v1/query" --data-urlencode "query=${loki_query}" --data-urlencode "limit=20")"

  local trace_id
  trace_id="$(echo "$loki_json" | jq -r '[.data.result[]?.values[]?[1] | (fromjson? // empty) | .trace_id | select(type == "string" and length > 0)][0] // ""')"

  local span_id
  span_id="$(echo "$loki_json" | jq -r '[.data.result[]?.values[]?[1] | (fromjson? // empty) | .span_id | select(type == "string" and length > 0)][0] // ""')"

  if [[ -z "$trace_id" || -z "$span_id" ]]; then
    echo "Failed to find trace_id/span_id in Loki logs."
    exit 1
  fi

  echo "Found correlated log trace_id=${trace_id} span_id=${span_id}"

  echo ""
  echo "Verifying trace exists in Jaeger..."
  local jaeger_trace
  jaeger_trace="$(curl -sS "${jaeger_url}/api/traces/${trace_id}")"

  local jaeger_span_count
  jaeger_span_count="$(echo "$jaeger_trace" | jq -r '[.data[]?.spans[]?] | length')"
  echo "Jaeger spans for ${trace_id}: ${jaeger_span_count}"

  if [[ "$jaeger_span_count" -eq 0 ]]; then
    echo "Trace ${trace_id} was not found in Jaeger."
    exit 1
  fi

  if [[ "$error_alert_count" -lt 1 || "$latency_alert_count" -lt 1 ]]; then
    echo "Expected high-error and high-latency alerts are not active yet."
    echo "Keep traffic running longer or increase duration (current: ${duration_minutes}m)."
    exit 1
  fi

  echo ""
  echo "Validation passed."
  echo "Alert -> trace -> log correlation confirmed."
}

main "$@"
