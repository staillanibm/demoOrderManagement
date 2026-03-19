KUBE_NAMESPACE=${KUBE_NAMESPACE:-"integration"}

TS1=$(date +%Y%m%d-%H%M%S)
DB2TS1=$(date +%Y-%m-%d-%H.%M.%S.000000)
sleep 1
TS2=$(date +%Y%m%d-%H%M%S)
DB2TS2=$(date +%Y-%m-%d-%H.%M.%S.000000)

FILENAME="orders_$(date +%Y%m%d-%H%M%S).csv"
LINE1="ORD-${TS1};${DB2TS1};CUST-5678;Stephane;stephane@email.com;12 Rue de la Paix;Paris;75002;FR;EUR;PROD-001|2|29.99;PROD-002|1|15.50;;;"
LINE2="ORD-${TS2};${DB2TS2};CUST-9012;Stephane;stephane@email.com;8 Avenue des Champs;Lyon;69001;FR;EUR;PROD-003|5|9.99;PROD-004|3|45.00;PROD-005|1|120.00;;"

BUSYBOX_POD=$(kubectl get pod -l app=busybox-pvc-browser -n ${KUBE_NAMESPACE} -o jsonpath='{.items[0].metadata.name}')
kubectl exec $BUSYBOX_POD -n ${KUBE_NAMESPACE} -- sh -c "mkdir -p /data/incoming && printf '%s\n%s\n' '${LINE1}' '${LINE2}' > /data/incoming/${FILENAME}"

echo "Injected ${FILENAME}"
echo "ORDER_ID_1=ORD-${TS1}"
echo "ORDER_ID_2=ORD-${TS2}"
