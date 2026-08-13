---
title: "Step-by-Step Installation Tutorial"
description: "Beginner-friendly tutorial to install a single-node Elastic Stack with unprivileged containers."
nav_order: 30
---

# Step-by-Step Installation Tutorial

This step-by-step tutorial teaches you how to deploy a single-node instance of Elasticsearch and Kibana utilizing hardened Wolfi images inside an isolated, rootless Podman network.

---

## 🎓 Learning Objectives
By the end of this tutorial, you will be able to:
1. Initialize an unprivileged, secure bridge network using Podman.
2. Build and run a single-node Elasticsearch database.
3. Hook up a secure Kibana frontend dashboard.
4. Verify server-to-server TLS authentication.

---

## 🛠️ Step 1: Pre-flight Verification

First, ensure that Podman is properly installed on your active Linux or WSL2 environment.

```bash
podman --version
```
*(Verify that Podman version 5.0+ or higher is active.)*

---

## 📂 Step 2: Provision Elasticsearch

Run our automated configuration script to download images, set secure certificates, and spin up the database container.

```bash
chmod +x setup_elasticsearch.sh
./setup_elasticsearch.sh
```

### What happened behind the scenes?
1. Sourced helper utilities from `scripts/utils.sh`.
2. Created a secure bridge network named `elastic_stack_net`.
3. Auto-generated high-entropy passwords for the root `elastic` user.
4. Exported the TLS certificate at `elk-wolfi/certs/http_ca.crt`.

---

## 🎨 Step 3: Run the Kibana Dashboard

With the backend active, run the dashboard set up to connect to the cluster:

```bash
chmod +x setup_kibana.sh
./setup_kibana.sh
```

Once completed, open your web browser and navigate to:
```text
http://localhost:5601
```

Log in using the `elastic` user and the password stored in `elk-wolfi/temp_credentials.txt`. You have successfully deployed a secure, local Elastic Stack!
