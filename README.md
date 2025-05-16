#Helm install
https://helm.sh/docs/intro/install/

curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

# 初期化処理（Vault、PostgreSQL、アプリのデプロイ）
./setup.sh

# リソース一式のクリーンアップ
./cleanup.sh

# アプリにローカルポート8080でアクセス（Flaskなどで5000番を使用している場合）
kubectl port-forward deployment/demo-app 8080:5000
or
./port-foward.sh

# ブラウザでアクセス（別ウィンドウで開く）
open http://localhost:8080/  # macOS
# start http://localhost:8080/  # Windows の場合



# VAULTの手動操作
export VAULT_TOKEN=root
export VAULT_ADDR=http://127.0.0.1:8200 

# psqlクライアントのインストール
sudo apt install -y postgresql-client

# 動的Secret払い出し
$ vault read database/creds/readonly-role

# データベースのSELECT(LEASEが5sなのでワンライナー）
$ vault read -format=json database/creds/readonly-role | jq -r '.data | "PGPASSWORD=" + .password + " psql -U " + .username + " -d demo -h localhost -p 5432 -c \"select * from messages;\""' | bash


# 処理シーケンス
https://www.planttext.com/

@startuml

autonumber

actor User
participant "Kubernetes API Server" as API
participant "Vault Agent Injector\n(Mutating Webhook)" as Injector
participant "Kubelet + Container Runtime" as Kubelet
participant "Vault Agent Sidecar" as Agent
participant "Vault Server" as Vault
participant "App Container\n(Flask)" as App
participant "PostgreSQL" as DB
== Pod 作成と初期化 ==
User -> API : Deployment (demo-app) apply
API -> Injector : AdmissionReview\n(annotations付きPod)
Injector -> API : Mutated Pod\n+ Vault Agent Sidecar\n+ Shared Volume
API -> Kubelet : Create Pod (App + Agent)
== Vault Agent の初期化 ==
Agent -> API : ServiceAccount JWT取得
Agent -> Vault : Authenticate via Kubernetes Auth Method
Vault -> Agent : Issue short-lived Vault Token
== Secret の取得とテンプレート展開 ==
Agent -> Vault : Read Secret\n(database/creds/readonly-role)
Vault -> Agent : Return dynamic DB credentials
Agent -> Agent : Render template to\n/vault/secrets/db-creds
== アプリケーション起動・利用 ==
App -> Agent : Wait for /vault/secrets/db-creds
App -> App : Read DB_USER/DB_PASSWORD from file
App -> DB : Connect and query demo DB
== Secret の TTL 監視 ==
Agent -> Vault : Renew or re-read Secret when TTL expires
Agent -> Agent : Update /vault/secrets/db-creds (overwrite)

@enduml
