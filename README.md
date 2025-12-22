# Todo Application: CI/CD & Kubernetes Orchestration

This repository contains the application source code, containerization logic, and automated deployment pipelines for the Todo Application.

## 📝 Application Overview
The **Todo Application** is a Node.js-based web application designed for task management.
* **Source**: The application logic in this repository was cloned from the [original source](https://github.com/Ankit6098/Todo-List-nodejs) for integration into this DevOps workflow.
* **Runtime**: Built using `node:18-alpine` as the base image.
* **Persistence**: Connects to a MongoDB database via the `mongoDbUrl` environment variable.
* **Networking**: The application listens on port **4000**.
* **High Availability**: Includes configured **Liveness** and **Readiness** probes to ensure container health.
* **App infrastructure repo**: [infrastructure repo](https://github.com/adel-hesham/Todo-application-infra) This repository includes the Terraform AWs infrastructure and Ansible nexus repo confiquration for this projejct

---

## 🖼️ Architecture & Pipeline Diagrams

### Infrastructure Overview
<img width="947" height="665" alt="image" src="https://github.com/user-attachments/assets/4a9bb262-8e9e-40cf-b1e2-232f61021521" />

### CI/CD Pipeline Flow
<img width="1027" height="499" alt="image" src="https://github.com/user-attachments/assets/5c089555-21df-46f8-8a79-de0c5c2bfc4e" />

---

## 🛠️ DevOps Toolchain
* **Docker**: Containerizes the application for environment consistency.
* **Jenkins (Pipeline-as-Code)**: Orchestrates the lifecycle from build to deployment.
* **Nexus Repository Manager**: Acts as the private Docker registry.
* **AWS SSM & Socat**: Establishes secure tunnels for pushing images to the private Nexus instance.
* **Kubernetes (K8s)**: Manages application scaling and self-healing.

---

## 🏗️ Deployment Logic
### 1. Kubernetes Manifests
* **Deployment**: Configured for the `prod`/`dev` namespace with resource limits (256Mi RAM / 200m CPU).
* **Service**: A `ClusterIP` service exposes the app internally on port 80.
* **Ingress**: Utilizes an **NGINX Ingress Controller** for external routing.
* **HPA**: Automatically scales the app between **1 and 5 replicas** based on resource use.

### 2. CI/CD Pipeline Stages
* **Continuous Integration**: Installs dependencies and performs an integration test by running a temporary container and verifying the endpoint via `curl`.
* **Continuous Deployment**: Authenticates with **AWS EKS**, updates secrets, and dynamically injects values (Nexus IP, DB URI) into YAML files using `sed`.

---

## 🚀 How to Use
1. **Prerequisites**: Ensure you have a running EKS cluster and a Nexus instance tagged with `Name=nexus-repo`.
2. **Configuration**: Store your MongoDB connection string in Jenkins credentials as `db-uri-secret`.
3. **Execution**: Trigger the Jenkins pipeline. Upon success, the application URL will be outputted in the logs.
