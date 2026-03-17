ROOT_URL=${ROOT_URL:-"http://localhost:5555"}
API_USER=${API_USER:-"Administrator"}
API_PASSWORD=${API_PASSWORD:-"manage"}
TS=${TS:-$(date +%Y%m%d-%H%M%S)}
ISO_TS=${ISO_TS:-$(date +%Y-%m-%dT%H:%M:%S.000)}

curl -X GET "${ROOT_URL}/OrdersAPI/orders" \
  -u "${API_USER}:${API_PASSWORD}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" -s | jq .