#!/bin/bash
set -v

ci_bin=$GOPATH/src/github.com/coredns/ci/build

# Start local docker image repository
docker run -d -p 5000:5000 --restart=always --name registry registry:2.6.2

# Start minikube
export MINIKUBE_WANTUPDATENOTIFICATION=false
export MINIKUBE_WANTREPORTERRORPROMPT=false
export MINIKUBE_HOME=$HOME
export CHANGE_MINIKUBE_NONE_USER=true
mkdir $HOME/.kube || true
touch $HOME/.kube/config

export KUBECONFIG=$HOME/.kube/config

minikube start --vm-driver=none --kubernetes-version=v1.12.0

# Wait for minkube's api service to be ready
for i in {1..60} # timeout for 2 minutes
do
   kubectl get po
   if [ $? -ne 1 ]; then
      break
  fi
  sleep 2
done

# Disable add-on manager
minikube addons disable addon-manager

#delete default coredns and deployment
kubectl delete deployment coredns -n kube-system

# Deploy test objects
kubectl create -f ${ci_bin}/kubernetes/dns-test.yaml

# Add federation labels to node
kubectl label nodes minikube failure-domain.beta.kubernetes.io/zone=fdzone
kubectl label nodes minikube failure-domain.beta.kubernetes.io/region=fdregion

# Deploy default test coredns
kubectl apply -f ${ci_bin}/kubernetes/coredns.yaml

# Start local proxy (for out-of-cluster tests)
kubectl proxy --port=8080 2> /dev/null &
echo -n $! > /var/run/kubectl_proxy.pid
sleep 3

