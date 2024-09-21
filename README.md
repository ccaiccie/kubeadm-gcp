# Kubernetes Cluster Setup on Google Cloud Platform (GCP)

This repository contains a script that automates the setup of a Kubernetes cluster on Google Cloud Platform (GCP). The script provisions a GCP Compute Engine instance, installs Kubernetes components, and initializes a single-node Kubernetes cluster.

## Features

- Provisions a **Spot VM** on GCP using the latest **Ubuntu 22.04** image.
- Installs **containerd**, **kubelet**, **kubeadm**, and **kubectl**.
- Initializes a **Kubernetes** cluster using `kubeadm` and configures the Flannel CNI plugin.
- Enables IP forwarding and sets up networking for Kubernetes.
- Optionally allows scheduling of Pods on the control plane node.

## Prerequisites

Before using this script, ensure that you have the following:

1. **Google Cloud SDK** (`gcloud`) installed and authenticated:
   - Install the SDK: https://cloud.google.com/sdk/docs/install
   - Authenticate: 
     ```bash
     gcloud auth login
     ```
   - Set your default project and zone:
     ```bash
     gcloud config set project <YOUR_PROJECT_ID>
     gcloud config set compute/zone <YOUR_ZONE>
     ```

2. **Billing Enabled** in your GCP project to provision resources.

## Setup Instructions

To run the script and create the Kubernetes cluster, follow these steps:

### Step 1: Clone the Repository

```bash
git clone https://github.com/ccaiccie/kubeadm-gcp.git
bash kubeadm-gcp.sh
