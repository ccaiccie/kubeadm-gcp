To configure Nginx in Kubernetes using a **volume mount** so that you can modify the settings from the host, you can use a **Persistent Volume (PV)** and a **Persistent Volume Claim (PVC)** to mount a specific directory from your Kubernetes host to the Nginx pod. This way, any changes you make to the configuration on the host will reflect in the Nginx container running in the Kubernetes cluster.

Here’s how you can achieve this setup using `kubeadm`:

### Step 1: Create a Directory on the Kubernetes Host for Nginx Configuration
First, create a directory on the host that will hold the Nginx configuration files. This directory will be mounted to the Nginx container.

```bash
sudo mkdir -p /mnt/data/nginx
```

You can place your custom Nginx configuration file (e.g., `nginx.conf`) in this directory.

For example:

```bash
sudo nano /mnt/data/nginx/nginx.conf
```

You can add your custom Nginx configuration here, for example:

```nginx
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name localhost;

        location / {
            return 200 'Welcome to Nginx on Kubernetes!';
            add_header Content-Type text/plain;
        }
    }
}
```

### Step 2: Create a Persistent Volume (PV) in Kubernetes

Now, create a **Persistent Volume (PV)** that points to the directory on the host (`/mnt/data/nginx`) that you created earlier.

Create a YAML file for the Persistent Volume, e.g., `nginx-pv.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nginx-pv
spec:
  capacity:
    storage: 1Gi  # Define the capacity for this volume
  accessModes:
    - ReadWriteOnce  # Allow read and write access from a single node
  hostPath:
    path: /mnt/data/nginx  # Host directory where Nginx config files are stored
```

### Step 3: Create a Persistent Volume Claim (PVC)

The Persistent Volume Claim (PVC) will be used by the Nginx pod to request access to the Persistent Volume (PV). Create a YAML file for the PVC, e.g., `nginx-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi  # Request 1Gi of storage
```

### Step 4: Create the Nginx Deployment with the Volume Mounted

Now, create the Nginx Deployment and mount the `nginx.conf` file from the host directory to the container. Create a YAML file for the Nginx Deployment, e.g., `nginx-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 1  # Number of Nginx pods to run
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest  # Use the official Nginx image
        ports:
        - containerPort: 80  # Expose port 80
        volumeMounts:
        - name: nginx-config-volume
          mountPath: /etc/nginx/nginx.conf  # Mount the config file in the container
          subPath: nginx.conf  # Mount just the file
      volumes:
      - name: nginx-config-volume
        persistentVolumeClaim:
          claimName: nginx-pvc  # Bind to the PVC
```

In this configuration:
- **`volumeMounts`**: This mounts the host directory’s `nginx.conf` file inside the Nginx container at `/etc/nginx/nginx.conf`.
- **`subPath: nginx.conf`**: Ensures that only the file `nginx.conf` is mounted instead of the entire directory.

### Step 5: Apply the YAML Files

Now, apply the configuration to your Kubernetes cluster.

1. Create the Persistent Volume (PV):
   ```bash
   kubectl apply -f nginx-pv.yaml
   ```

2. Create the Persistent Volume Claim (PVC):
   ```bash
   kubectl apply -f nginx-pvc.yaml
   ```

3. Create the Nginx Deployment:
   ```bash
   kubectl apply -f nginx-deployment.yaml
   ```

### Step 6: Expose the Nginx Service

If you want to expose the Nginx service using a **NodePort**, you can create a Service for it. Here’s an example `nginx-service.yaml` to expose it on a NodePort:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 32000  # The NodePort to access from outside the cluster
```

Apply the service file:

```bash
kubectl apply -f nginx-service.yaml
```

### Step 7: Verify the Setup

You can verify the Nginx pod and service are running with:

```bash
kubectl get pods
kubectl get svc
```

You can now access the Nginx server via the NodePort (e.g., `http://<node-ip>:32000`). Any changes made to the `nginx.conf` file on the host at `/mnt/data/nginx/nginx.conf` will be reflected in the Nginx container.

### Summary

1. **Persistent Volume (PV)**: Binds the host directory (`/mnt/data/nginx`) to Kubernetes.
2. **Persistent Volume Claim (PVC)**: Requests storage from the PV.
3. **Nginx Deployment**: Mounts the host's Nginx configuration file into the Nginx container.
4. **NodePort Service**: Exposes Nginx on a port (e.g., `32000`) to access it externally.

This setup allows you to manage Nginx configuration files from the host and apply changes directly to the running Nginx container inside Kubernetes.
