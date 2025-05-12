#!/bin/bash
set -euo pipefail

NAMESPACE=default
VAULT_HELM_RELEASE=vault
VAULT_HELM_REPO=https://helm.releases.hashicorp.com
VAULT_VALUES=01-vault-values.yaml
CHECK_TIMEOUT=120

function error_report() {
  local message=$1
  local output_dir="error_logs"
  mkdir -p $output_dir

  echo "❌ エラー: $message"

  echo "📦 ログを収集しています..."
  {
    echo "======= [Vault Helm Release Status] ======="
    helm list -n $NAMESPACE || echo "Helm list failed"

    echo "======= [Vault Pods] ======="
    kubectl get pods -n $NAMESPACE -o wide

    echo "======= [Vault Injector Logs] ======="
    kubectl logs -l app.kubernetes.io/name=vault-agent-injector || echo "Vault Injector logs failed"

    echo "======= [Vault Init Job Logs] ======="
    kubectl logs job/vault-init || echo "vault-init job logs failed"

    echo "======= [App Logs] ======="
    kubectl logs -l app=demo-app -c app || echo "app logs failed"

    echo "======= [Describe All Resources] ======="
    kubectl describe all -n $NAMESPACE
  } > "$output_dir/setup_error_report.txt" 2>&1

  echo
  echo "-------"
  echo "エラー内容は以下の通りです。調査に必要な情報を下記に取得しましたので、ChatGPT に問い合わせください。"
  echo "$message"
  echo "ログファイル: $(realpath $output_dir/setup_error_report.txt)"
  echo "-------"

  exit 1
}

echo "🚀 RBACリソースの適用（Vault用 ServiceAccount & RoleBinding）"
kubectl apply -f 00-rbac.yaml || error_report "00-rbac.yaml の適用に失敗しました。"

echo "🚀 Helmリポジトリの追加と更新"
helm repo add hashicorp $VAULT_HELM_REPO || true
helm repo update

echo "🚀 Vault Helmチャートをインストール（またはスキップ）"
if helm list -n $NAMESPACE | grep -q "$VAULT_HELM_RELEASE"; then
  echo "✅ Helmリリース '$VAULT_HELM_RELEASE' はすでに存在します。スキップします。"
else
  helm install $VAULT_HELM_RELEASE hashicorp/vault \
    -f $VAULT_VALUES \
    --namespace $NAMESPACE \
    --create-namespace || error_report "Vault Helmインストールに失敗しました。"
fi

echo "⏳ Vault InjectorがReadyになるまで待機..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=vault-agent-injector --timeout=${CHECK_TIMEOUT}s \
  || error_report "Vault Agent Injector PodがReadyになりません。"

echo "📦 ConfigMapとPostgreSQL、Vault Init Jobを適用"
kubectl apply -f 02-configmap-postgres-init.yaml || error_report "02-configmap-postgres-init.yaml の適用に失敗しました。"
kubectl apply -f 03-configmap-readonly-role-sql.yaml || error_report "03-configmap-readonly-role-sql.yaml の適用に失敗しました。"
kubectl apply -f 05-postgres-deployment.yaml || error_report "05-postgres-deployment.yaml の適用に失敗しました。"
kubectl apply -f 06-vault-init-job.yaml || error_report "06-vault-init-job.yaml の適用に失敗しました。"
kubectl apply -f 07-postgres-init-job.yaml || error_report "07-postgres-init-job.yaml の適用に失敗しました。"

echo "📦 FlaskアプリのDeploymentを適用"
kubectl apply -f 04-demo-app-deployment.yaml || error_report "04-demo-app-deployment.yaml の適用に失敗しました。"

echo "⏳ PostgreSQL Pod がReadyになるまで待機中..."
kubectl wait --for=condition=Ready pod -l app=postgres --timeout=${CHECK_TIMEOUT}s \
  || error_report "Postgres PodがReadyになりません。"

echo "⏳ Flask アプリPod (label=app=demo-app) がReadyになるまで待機中..."
kubectl wait --for=condition=Ready pod -l app=demo-app --timeout=${CHECK_TIMEOUT}s \
  || error_report "Flaskアプリ Pod (label=app=demo-app) がReadyになりません。"

echo "🎉 セットアップ成功！Vault Agent Injector による注入と Flask アプリの起動が確認できました。"

