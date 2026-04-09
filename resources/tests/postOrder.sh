ROOT_URL=${ROOT_URL:-"http://localhost:5555"}
API_USER=${API_USER:-"Administrator"}
API_PASSWORD=${API_PASSWORD:-"manage"}
TS=${TS:-$(date +%Y%m%d-%H%M%S)}
ISO_TS=${ISO_TS:-$(date +%Y-%m-%dT%H:%M:%S.000)}

RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST "${ROOT_URL}/OrdersAPI/orders" \
  -u "${API_USER}:${API_PASSWORD}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "orderRequest": {
      "id": "ORD-'"${TS}"'",
      "date": "'"${ISO_TS}"'",
      "customer": {
        "id": "CUST-123",
        "name": "John Doe",
        "email": "john.doe@example.com"
      },
      "shippingAddress": {
        "street": "123 Main Street",
        "city": "Paris",
        "postalCode": "75001",
        "country": "FR"
      },
      "currency": "EUR",
      "items": {
        "item": [
          {
            "id": "ITEM-001",
            "quantity": "2",
            "unitPrice": "29.99"
          },
          {
            "id": "ITEM-002",
            "quantity": "1",
            "unitPrice": "49.99"
          }
        ]
      }
    }
  }')

STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq .

if [ "$STATUS" != "202" ]; then
  echo "POST /orders failed: HTTP $STATUS"
  exit 1
fi

echo "POST /orders/ORD-${TS}: OK"