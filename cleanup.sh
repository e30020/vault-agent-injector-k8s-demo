#!/bin/bash
set -euo pipefail

NAMESPACE=default

echo "🧹 Deleting Flask App Deployment..."
kubectl delete deployment demo-app -n $NAMESPACE --ignore-not-found
kubectl delete pod -l app=demo-app -n $NAMESPACE --ignore-not-found --force --grace-period=0

echo "🧹 Deleting Nginx TLS Deployment と Service..."
kubectl delete -f 08-nginx-deployment.yaml --ignore-not-found
kubectl delete -f 09-nginx-service.yaml --ignore-not-found
kubectl delete pod -l app=nginx-tls -n $NAMESPACE --ignore-not-found --force --grace-period=0
kubectl delete configmap nginx-config -n $NAMESPACE --ignore-not-found

echo "🧹 Deleting Postgres Deploymentとリソース..."
kubectl delete -f 05-postgres-deployment.yaml --ignore-not-found
kubectl delete pod -l app=postgres -n $NAMESPACE --ignore-not-found --force --grace-period=0
kubectl delete replicaset -l app=postgres -n $NAMESPACE --ignore-not-found --force --grace-period=0

echo "🧹 Deleting Vault Init Job..."
kubectl delete job vault-init -n $NAMESPACE --ignore-not-found
kubectl delete -f 06-vault-init-job.yaml --ignore-not-found
kubectl delete pod -l job-name=vault-init -n $NAMESPACE --ignore-not-found --force --grace-period=0

echo "🧹 Deleting Postgres Init Job..."
kubectl delete job postgres-init -n $NAMESPACE --ignore-not-found
kubectl delete -f 07-postgres-init-job.yaml --ignore-not-found

echo "🧹 Deleting ConfigMap と Secret..."
kubectl delete configmap postgres-init-sql -n $NAMESPACE --ignore-not-found
kubectl delete configmap readonly-role-sql -n $NAMESPACE --ignore-not-found
kubectl delete configmap vault-agent-config -n $NAMESPACE --ignore-not-found || true
kubectl delete configmap nginx-config -n $NAMESPACE --ignore-not-found
kubectl delete secret vault-agent-creds -n $NAMESPACE --ignore-not-found

echo "🧹 Deleting RBAC リソース..."
kubectl delete -f 00-rbac.yaml --ignore-not-found
kubectl delete serviceaccount vault -n $NAMESPACE --ignore-not-found
kubectl delete role role-tokenreview-binding -n $NAMESPACE --ignore-not-found
kubectl delete rolebinding role-tokenreview-binding -n $NAMESPACE --ignore-not-found
kubectl delete clusterrolebinding role-tokenreview-binding --ignore-not-found

echo "🧹 Helmでインストールされた Vault を削除..."
helm uninstall vault --namespace $NAMESPACE || true

echo "🧹 PVC や Vault 関連Pod を強制削除（万一のため）..."
kubectl delete pod -l app.kubernetes.io/name=vault -n $NAMESPACE --force --grace-period=0 --ignore-not-found
kubectl delete pod -l app.kubernetes.io/name=vault-agent-injector -n $NAMESPACE --force --grace-period=0 --ignore-not-found
kubectl delete pvc -l app.kubernetes.io/name=vault -n $NAMESPACE --ignore-not-found

echo "✅ Cleanup completed."
