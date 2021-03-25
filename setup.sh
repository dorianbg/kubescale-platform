if [[ -z "${NAMESPACE}" ]]; then
  NAMESPACE_VAR="Some default value because NAMESPACE is undefined"
else
  NAMESPACE_VAR="${NAMESPACE}"
fi

# Install the support for local path storage
kubectl apply -f platform/kubernetes/storage/local-path.yaml

# Install the Prometheus monitoring operator using helm
helm install stable/prometheus -f platform/helm/prometheus/values.yaml --name prometheus-release --namespace $NAMESPACE_VAR --debug --version 11.12.0

# Install Prometheus custom metrics adapter using helm
helm install stable/prometheus-adapter -f platform/helm/custom-metrics-prometheus-adapter/values.yaml --name prometheus-metrics-adapter --namespace $NAMESPACE_VAR --debug --version 2.5.0

# Install Grafana using helm
helm install stable/grafana -f platform/helm/grafana/values.yaml --name grafana-release --namespace $NAMESPACE_VAR --debug --version 5.5.5

# Install kube-eagle for monitoring using helm
helm repo add kube-eagle https://raw.githubusercontent.com/cloudworkz/kube-eagle-helm-chart/master
helm repo update
helm install --name=kube-eagle kube-eagle/kube-eagle

#  Configure and install the Envoy load balancer
kubectl apply -f platform/kubernetes/envoy/configmap-lb-envoy.yaml
kubectl apply -f platform/kubernetes/envoy/service-deployment-lb-envoy.yaml

# Add a secret so you can pull images from the Google Cloud platform hosted docker repository
# todo potentially remove this if images are published publically
kubectl create secret docker-registry gcr-json-key \
    --docker-server=gcr.io --docker-username=_json_key \
    --docker-password="$(cat {YOUR_SECRET_LOCATION})"  \
    --docker-email=some@gmail.com

# Add the secret containing email username and password that are used for the auto-scaler to send email notification
# eg.
kubectl apply -f platform/kubernetes/secrets/email-secret.yaml

# Install the python flask web application
kubectl apply -f platform/kubernetes/web-application/service-deployment-pythonwebapp.yaml

# Install the gatling custom simulation config map that contains the load generation scripts
kubectl apply -f platform/kubernetes/gatling/configmap-gatling-custom-simulation-def.yaml

# Below command will setup a gatling cron job or you can run individual experiment now with the experiment_runner.sh script
# Before that you should probably run one of the gatling cron jobs that can run on a schedule various simulations specified in the `gatling-custom-simulation-configmap.yaml`.
# The cron job is created as following and inside of it, it is possible to tweak the exact simulation that will be ran on the schedule:
kubectl apply -f platform/kubernetes/gatling/cron-gatling-pythonwebapp.yaml

# Add a KubeConfig configmap - this contains the contents of the KUBE_CONFIG file and is necessary for the auto-scaler to be able to talk with the cluster
kubectl apply -f platform/kubernetes/secrets/kube-config-configmap.yaml

# Deploy the configuration for the KubeScale auto-scaler
kubectl apply -f platform/kubernetes/kubescale-autoscaler/configmap-autoscaler-webapp.yaml
# Deploy the KubeScale auto-scaler
kubectl apply -f platform/kubernetes/kubescale-autoscaler/deployment-autoscaler.yaml
