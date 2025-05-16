#!/bin/bash

# Vault Pod名を取得
VAULT_POD=$(kubectl get pod -l app.kubernetes.io/name=vault -o jsonpath="{.items[0].metadata.name}")
if [ -z "$VAULT_POD" ]; then
 echo "❌ Vault Pod が見つかりません。"
 exit 1
fi

# demo-app Pod名を取得
APP_POD=$(kubectl get pod -l app=demo-app -o jsonpath="{.items[0].metadata.name}")
if [ -z "$APP_POD" ]; then
 echo "❌ demo-app Pod が見つかりません。"
 exit 1
fi

# postgres Pod名を取得
PG_POD=$(kubectl get pod -l app=postgres -o jsonpath="{.items[0].metadata.name}")
if [ -z "$PG_POD" ]; then
 echo "❌ postgres Pod が見つかりません。"
 exit 1
fi


echo "✅ Vault Pod: $VAULT_POD"
echo "✅ App Pod:  $APP_POD"
echo "✅ Postgres Pod:  $PG_POD"


# Vault のポートフォワーディング（8200）
echo "🚀 Vault ポートフォワーディングを開始します (localhost:8200)"
kubectl port-forward pod/$VAULT_POD 8200:8200 > /tmp/port-forward-vault.log 2>&1 &

# demo-app のポートフォワーディング（8080）
echo "🚀 demo-app ポートフォワーディングを開始します (localhost:8080)"
kubectl port-forward pod/$APP_POD 8080:5000 > /tmp/port-forward-app.log 2>&1 &

# postgres のポートフォワーディング（5432）
echo "🚀 postgres ポートフォワーディングを開始します (localhost:5432)"
kubectl port-forward pod/$PG_POD 5432:5432 > /tmp/port-forward-app.log 2>&1 &

echo "🎉 両方のポートフォワーディングをバックグラウンドで実行中"
echo "📄 ログ: /tmp/port-forward-vault.log, /tmp/port-forward-app.log"
echo "🛑 終了するには: 'kill $(jobs -p)' または 'pkill -f port-forward'"
