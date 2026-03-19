ROOT_URL=${ROOT_URL:-"http://localhost:5555"}
API_USER=${API_USER:-"Administrator"}
API_PASSWORD=${API_PASSWORD:-"manage"}

if [ -z "$ORDER_ID" ]; then
  echo "ERROR: ORDER_ID is required"
  exit 1
fi

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${ROOT_URL}/OrdersAPI/orders/${ORDER_ID}" \
  -u "${API_USER}:${API_PASSWORD}" \
  -H "Accept: application/json")

STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

echo "$BODY" | jq .

if [ "$STATUS" != "200" ]; then
  echo "GET /orders/${ORDER_ID} failed: HTTP $STATUS"
  exit 1
fi