#!/bin/bash

POD_NAME=$(kubectl get pod -l app=nginx-tls -o jsonpath="{.items[0].metadata.name}")
CONTAINER_NAME=nginx

echo "🔍 現在の証明書情報（Before）:"
OLD_INFO=$(kubectl exec -it "$POD_NAME" -c "$CONTAINER_NAME" -- openssl x509 -in /etc/nginx/ssl/tls.crt -noout -subject -enddate -serial)
echo "$OLD_INFO"

read -p $'\n🚀 Enterキーで Vault 側で証明書を revoke → issue します...'

echo -e "\n🔄 Vault: 現在の証明書を revoke します..."

# Vault 内の保存済み証明書から最新のコロン付きシリアル番号を取得
SERIAL_COLON=$(vault list -format=json pki-int/certs | jq -r '.[0]')
echo "▶ vault write pki-int/revoke serial_number=\"$SERIAL_COLON\""
vault write pki-int/revoke serial_number="$SERIAL_COLON"

echo -e "\n✏️ Vault: 新しい証明書を発行し、ファイルに出力します..."
echo "▶ vault write -format=json pki-int/issue/nginx common_name=\"nginx.example.com\" ttl=72h store_certificate=true"
vault write -format=json pki-int/issue/nginx \
  common_name="nginx.example.com" \
  ttl=72h \
  store_certificate=true > issued_cert.json

CRT=$(jq -r '.data.certificate' < issued_cert.json)
KEY=$(jq -r '.data.private_key' < issued_cert.json)
CHAIN0=$(jq -r '.data.ca_chain[0]' < issued_cert.json)
CHAIN1=$(jq -r '.data.ca_chain[1]' < issued_cert.json)

echo "$CRT"$'\n'"$CHAIN0"$'\n'"$CHAIN1" > tls.crt
echo "$KEY" > tls.key

echo -e "\n📦 Kubernetes: 証明書を再注入（nginx Pod 内へ）"
echo "▶ kubectl cp tls.crt $POD_NAME:/etc/nginx/ssl/tls.crt -c $CONTAINER_NAME"
kubectl cp tls.crt "$POD_NAME:/etc/nginx/ssl/tls.crt" -c "$CONTAINER_NAME"
echo "▶ kubectl cp tls.key $POD_NAME:/etc/nginx/ssl/tls.key -c $CONTAINER_NAME"
kubectl cp tls.key "$POD_NAME:/etc/nginx/ssl/tls.key" -c "$CONTAINER_NAME"

echo -e "\n🔁 Nginx: 証明書を再読み込み（nginx -s reload）"
kubectl exec -it "$POD_NAME" -c "$CONTAINER_NAME" -- nginx -s reload

echo -e "\n🔍 新しい証明書情報（After）:"
NEW_INFO=$(kubectl exec "$POD_NAME" -c "$CONTAINER_NAME" -- openssl x509 -in /etc/nginx/ssl/tls.crt -noout -subject -enddate -serial)
echo "$NEW_INFO"

# 表形式で出力
OLD_SUBJECT=$(echo "$OLD_INFO" | grep -i subject | sed 's/subject=//' | tr -d '\r\n')
OLD_END=$(echo "$OLD_INFO" | grep -i notAfter | sed 's/notAfter=//' | tr -d '\r\n')
OLD_SERIAL=$(echo "$OLD_INFO" | grep -i serial | sed 's/serial=//' | tr -d '\r\n')

NEW_SUBJECT=$(echo "$NEW_INFO" | grep -i subject | sed 's/subject=//' | tr -d '\r\n')
NEW_END=$(echo "$NEW_INFO" | grep -i notAfter | sed 's/notAfter=//' | tr -d '\r\n')
NEW_SERIAL=$(echo "$NEW_INFO" | grep -i serial | sed 's/serial=//' | tr -d '\r\n')


# 表出力（echo + awk）
echo ""
echo "📊 修正前／修正後 証明書情報："
echo ""
echo "| 項目     | 修正前                                | 修正後                                |"
echo "|----------|----------------------------------------|----------------------------------------|"

printf "%s\n" "Subject|$OLD_SUBJECT|$NEW_SUBJECT" \
              "NotAfter|$OLD_END|$NEW_END" \
              "Serial|$OLD_SERIAL|$NEW_SERIAL" | \
awk -F"|" '{ printf "| %-9s | %-40s | %-40s |\n", $1, $2, $3 }'



echo -e "\n✅ 完了しました"
