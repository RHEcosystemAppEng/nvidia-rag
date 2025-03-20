#! /bin/bash

read -r -p "Enter NGC API Key: " NVIDIA_API_KEY
echo "$NVIDIA_API_KEY"

kubectl create namespace rag
kubectl create secret -n rag docker-registry ngc-secret --docker-server=nvcr.io --docker-username='$oauthtoken' --docker-password=$NVIDIA_API_KEY
kubectl label secret ngc-secret -n rag app.kubernetes.io/managed-by=Helm
kubectl annotate secret ngc-secret -n rag meta.helm.sh/release-name=rag meta.helm.sh/release-namespace=rag

kubectl create secret -n rag generic nvidia-nim-secrets --from-literal=NGC_API_KEY=$NVIDIA_API_KEY
kubectl label secret nvidia-nim-secrets -n rag app.kubernetes.io/managed-by=Helm
kubectl annotate secret nvidia-nim-secrets -n rag meta.helm.sh/release-name=rag meta.helm.sh/release-namespace=rag

DOMAIN=$(kubectl get Ingress.config.openshift.io/cluster -o jsonpath='{.spec.domain}')

helm upgrade --install rag . -n rag \
  --set imagePullSecret.password=$NVIDIA_API_KEY \
  --set nvidia-nim-llama-32-nv-embedqa-1b-v2.nim.ngcAPIKey=$NVIDIA_API_KEY \
  --set text-reranking-nim.nim.ngcAPIKey=$NVIDIA_API_KEY \
  --set nim-llm.model.ngcAPIKey=$NVIDIA_API_KEY \
  --set text-reranking-nim.acceleratorName=g5-gpu \
  --set-json text-reranking-nim.tolerations='[{"key":"g5-gpu","effect":"NoSchedule","operator":"Exists"}]' \
  --set nvidia-nim-llama-32-nv-embedqa-1b-v2.acceleratorName=g5-gpu \
  --set-json nvidia-nim-llama-32-nv-embedqa-1b-v2.tolerations='[{"key":"g5-gpu","effect":"NoSchedule","operator":"Exists"}]' \
  --set nim-llm.acceleratorName=p4-gpu \
  --set-json nim-llm.tolerations='[{"key":"p4-gpu","effect":"NoSchedule","operator":"Exists"}]' \
  --set-json milvus.tolerations='[{"key":"g5-gpu","effect":"NoSchedule","operator":"Exists"}]' \
  --set ragServer.env.APP_EMBEDDINGS_SERVERURL="https://nemo-embedding-ms-rag.$DOMAIN" \
  --set ragServer.env.APP_RANKING_SERVERURL="https://nemo-ranking-ms-rag.$DOMAIN" \
  --set ragServer.env.APP_LLM_SERVERURL="https://nim-llm-rag.$DOMAIN" \
  --set ragServer.env.APP_LLM_MODELNAME="meta/llama3-8b-instruct" \

oc adm policy add-scc-to-user anyuid -z rag-minio -n rag

echo "Listing pods..."
kubectl get pods -n rag

echo "Listing services..."
kubectl get svc -n rag
