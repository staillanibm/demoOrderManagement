ROOT_URL=${ROOT_URL:-"http://localhost:5555"}
API_USER=${API_USER:-"Administrator"}
API_PASSWORD=${API_PASSWORD:-"manage"}

RESPONSE=$(curl -k -s -w "\n%{http_code}" -X GET "${ROOT_URL}/OrdersAPI/orders" \
  -u "${API_USER}:${API_PASSWORD}" \
  -H "Accept: application/json")

STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq .

if [ "$STATUS" != "200" ]; then
  echo "GET /orders failed: HTTP $STATUS"
  exit 1
fi