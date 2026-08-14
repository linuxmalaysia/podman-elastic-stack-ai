---
title: "Podman Compose Configurations"
description: "Reference catalog for unprivileged Podman Compose stacks deployed by this project."
nav_order: 12
---

# Podman Compose Configurations

This document details the configuration layouts, volumes, networks, and environment variables defined in our service compose manifests.

---

## 📦 Elasticsearch Stack (`elk-wolfi/podman-compose.yml`)

The main stack builds a secure, local instance of Elasticsearch utilizing an unprivileged Wolfi base image.

### Service Definition Specs

* **Image**: `docker.elastic.co/elasticsearch/elasticsearch-wolfi:9.4.4` (or as overridden by deployment tags).
* **Network Mode**: Joined to a dedicated bridge network (`elastic_stack_net`).
* **Environment Variables**:
  - `discovery.type`: Configured to `single-node` to run localized testing efficiently.
  - `xpack.security.enabled`: Set explicitly to `true`.
  - `xpack.security.enrollment.enabled`: Sourced to support automatic Kibana joining.
* **Volume Mounts**:
  - `es_data_01`: Binds safely to `/usr/share/elasticsearch/data`.
  - `/opt/dsom-persistence`: Local persistent volume boundaries.

---

## 🎨 Kibana Stack (`elk-wolfi/podman-compose-kibana.yml`)

The companion frontend dashboard connecting securely to the core analytics cluster.

### Service Definition Specs

* **Image**: `docker.elastic.co/kibana/kibana-wolfi:9.4.4`
* **Ports**: Exposes standard dashboard port `5601`.
* **Volume Mounts**:
  - Mounts custom `kibana.yml` dynamically at runtime.
