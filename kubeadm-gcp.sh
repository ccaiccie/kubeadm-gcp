PROJECT_ID=$(gcloud config get-value project)
ZONE=$(gcloud config get-value compute/zone)
UBUNTU_IMAGE=$(gcloud compute images list --project=ubuntu-os-cloud --filter="name~'ubuntu-2204-jammy' AND architecture='X86_64'" --sort-by="~creationTimestamp" --limit=1 --format="value(name)")

# Create the Compute Instance
gcloud compute instances create kubemain \
 --machine-type=n2-standard-2 \
 --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
 --provisioning-model=SPOT \
 --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
 --create-disk=auto-delete=yes,boot=yes,device-name=kubemain,image=projects/ubuntu-os-cloud/global/images/$UBUNTU_IMAGE,mode=rw,size=50,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-balanced \
 --no-shielded-secure-boot \
 --shielded-vtpm \
 --tags=kubemain \
 --zone=$ZONE \
 --enable-nested-virtualization \
 --instance-termination-action=stop \
 --can-ip-forward \
 --metadata serial-port-enable=TRUE,startup-script="#!/bin/bash

# Redirect stdout and stderr to the log file
exec > /var/log/startup-script.log 2>&1

if [ ! -f /opt/env/startup-script-ran ]; then
    mkdir -p /opt/env
    export DEBIAN_FRONTEND=\"noninteractive\"
    echo \"debconf debconf/frontend select Noninteractive\" | debconf-set-selections
    echo \"APT::Get::Assume-Yes \\\"true\\\";\" > /tmp/_tmp_apt.conf
    export APT_CONFIG=/tmp/_tmp_apt.conf
    apt-get update
    apt-get install -y containerd socat conntrack apt-transport-https ca-certificates curl gnupg lsb-release

    # Configure containerd
    mkdir -p /etc/containerd
    containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' > /etc/containerd/config.toml
    systemctl restart containerd
    systemctl enable containerd

    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1
    echo \"net.ipv4.ip_forward = 1\" | tee /etc/sysctl.d/99-ipforward.conf

    # Disable swap
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab

    # Add Kubernetes signing key and repository
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo \"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /\" | tee /etc/apt/sources.list.d/kubernetes.list

    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl

    # Initialize Kubernetes cluster
    kubeadm init --pod-network-cidr=\"10.244.0.0/16\"

    # Set up local kubeconfig for the root user
    export KUBECONFIG=/etc/kubernetes/admin.conf
    mkdir -p /root/.kube
    cp -i /etc/kubernetes/admin.conf /root/.kube/config

    # Install Flannel CNI plugin for networking
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

    # Allow scheduling pods on the control-plane node (optional for single-node cluster)
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

    # Enable kubectl autocompletion
    echo \"source <(kubectl completion bash)\" | sudo tee -a /etc/bash.bashrc
    echo \"export KUBECONFIG=/etc/kubernetes/admin.conf\" | sudo tee -a /etc/bash.bashrc
    sudo chmod a+r /etc/kubernetes/admin.conf

    touch /opt/env/startup-script-ran
fi
"
