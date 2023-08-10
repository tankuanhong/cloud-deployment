#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/kubernetes.conf" || { err "${SCRIPT_PATH}/conf/kubernetes.conf is missing" >&2; exit 1; }

# function to check if command exist
command_exist() {
  type "$1" > /dev/null 2>&1
}

# function to check if service is active
service_active() {
  systemctl is-active --quiet $1
}

# this script is only tested on Ubuntu 20.04
if [ $(lsb_release -si) != "Ubuntu" ] || [ $(lsb_release -sr) != "20.04" ]; then
  err "This server is not running Ubuntu 20.04"
  err "Terminating script..."
  exit 1
fi

initialize_kubeadm() {
  info "Initializing kubeadm..." && \
    kubeadm init \
    --pod-network-cidr=${KUBE_POD_NETWORK} \
    --service-cidr=${KUBE_SVC_NETWORK} \
    --apiserver-advertise-address=${KUBE_MASTER} \
    --kubernetes-version=${KUBE_VERSION} && \
    mkdir -p $HOME/.kube && \
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
    chown $(id -u):$(id -g) $HOME/.kube/config
}

install_calico() {
  info "Installing Calico networking plugin..." && \
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/tigera-operator.yaml && \
    wget -O "${SCRIPT_PATH}/calico-custom-resources.yaml" https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/custom-resources.yaml && \
    sed -i "s@cidr:.*@cidr: ${KUBE_POD_NETWORK}@" "${SCRIPT_PATH}/calico-custom-resources.yaml" && \
    kubectl create -f "${SCRIPT_PATH}/calico-custom-resources.yaml"
}

encrypt_etcd() {
  info "Setting up encryption for etcd..." && \
    ETCD_SECRET=$(head -c 32 /dev/urandom | base64) && \
    mkdir /etc/kubernetes/enc && \
    cat <<EOF | sudo tee /etc/kubernetes/enc/enc.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ETCD_SECRET}
      - identity: {}
EOF

  chmod 600 /etc/kubernetes/enc/enc.yaml && \
    sed -i '/enable-bootstrap-token-auth/a\    - --encryption-provider-config=\/etc\/kubernetes\/enc\/enc.yaml' /etc/kubernetes/manifests/kube-apiserver.yaml && \
    sed -i '/volumeMounts:/a\    - name: enc\n      mountPath: \/etc\/kubernetes\/enc\n      readonly: true' /etc/kubernetes/manifests/kube-apiserver.yaml && \
    sed -i '/volumes:/a\  - name: enc\n    hostPath:\n      path: \/etc\/kubernetes\/enc\n      type: DirectoryOrCreate' /etc/kubernetes/manifests/kube-apiserver.yaml && \
    until kubectl get nodes; do sleep 10; done
}

initialize_kubeadm
install_calico
encrypt_etcd

} # this ensures the entire script is downloaded #