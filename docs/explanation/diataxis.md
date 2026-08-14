---
title: "Diátaxis Framework Integration"
description: "Explanation of how the Diátaxis documentation structure is adopted, integrated, and maintained in our project."
nav_order: 42
---

# Diátaxis Framework Integration

This page explains why and how our project adopts the **Diátaxis Framework** to organize, govern, and maintain our technical documentation ecosystem.

---

## 🧭 What is Diátaxis?

The [Diátaxis Framework](https://diataxis.fr/) is a systematic approach to technical writing that classifies technical content into four distinct, complementary user needs:

```text
               |  PRACTICAL STEP  |  THEORETICAL STEP
---------------+------------------+-------------------
ACQUISITION    |    Tutorials     |    Explanation
---------------+------------------+-------------------
APPLICATION    |   How-To Guides  |     Reference
```

---

## 🛠️ How we apply Diátaxis in this Project

Our document architecture is separated cleanly inside the `docs/` workspace to solve explicit user situations:

### 1. Tutorials (Learning-Oriented)
- **Path**: `docs/tutorials/`
- **Goal**: Guided, step-by-step learning lessons for beginners. Focuses on learning through execution.
- **Example**: Creating a single-node deployment from scratch without needing complex orchestration options.

### 2. How-To Guides (Problem-Oriented)
- **Path**: `docs/how-to/`
- **Goal**: Practical directions to help you solve a specific task or real-world problem.
- **Example**: Overriding host memory parameters, or setting up TLS trust across local servers.

### 3. Reference (Information-Oriented)
- **Path**: `docs/reference/`
- **Goal**: Absolute technical accuracy, CLI variables, APIs, inputs, outputs, and programmatic signatures.
- **Example**: Sourcing the exact list of options accepted by the `setup_elasticsearch.sh` script.

### 4. Explanation (Understanding-Oriented)
- **Path**: `docs/explanation/`
- **Goal**: High-level conceptual clarification, component boundaries, architectural choices, and security decisions.
- **Example**: Explaining why rootless execution matrices prevent container privilege escalation.

---

## 📈 Long-term Maintenance

To ensure our documentation never goes stale, we enforce automatic link audits and snippet validation using GitHub Actions pipelines (`.github/workflows/docs-ci.yml`). This maintains dual compatibility across GitBook sitemaps and compiled GitHub Pages dashboards.
