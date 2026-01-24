# Observability Architecture Diagram Generation Prompt

## 🎨 Image Generation Prompt for ChatGPT/AI Tools

Copy and paste this prompt to generate a professional observability architecture diagram:

---

**Create a professional, modern architecture diagram for a unified observability platform with the following specifications:**

## **Overall Layout:**

- **Style**: Clean, modern, enterprise-grade architecture diagram
- **Colors**: Use a professional color scheme with blues, greens, and grays
- **Format**: Horizontal layout, high resolution, suitable for documentation
- **Background**: Light gray or white background with subtle grid lines

## **Main Components (Top to Bottom):**

### **1. Top Layer - Unified Grafana Dashboard**

- Large rectangular container labeled "**Unified Grafana Dashboard**"
- Subtitle: "Single Pane of Glass"
- Color: Dark blue header with light blue background
- Include Grafana logo icon
- Show "Real-time Monitoring & Analytics" text

### **2. Second Layer - Four Pillars of Observability**

Create four equal-sized rectangular containers in a row:

**A. METRICS (Left)**

- Container color: Green
- Title: "METRICS"
- Components listed vertically:
  - Prometheus (with icon)
  - AlertManager
  - Blackbox Exporter
  - Node Exporter
- Data flow arrow pointing up to Grafana
- **Alert flow arrows** pointing right to "Alert Routing" section

**Alert Routing Section (Between METRICS and LOGS):**

- Vertical container labeled "**AlertManager Routing**"
- Color: Yellow/Orange gradient
- Show three output channels with severity-based routing:
  - **Critical Alerts** → Slack #critical-alerts (Red arrow, thick line)
    - Include "15min response SLA" label
    - Show PagerDuty escalation after 5min (Red dotted arrow)
  - **Warning Alerts** → Slack #warnings (Orange arrow, medium line)
    - Include "1hr response SLA" label
  - **Security Alerts** → Slack #security-team (Purple arrow, thick line)
    - Include "5min response SLA" label
    - Show "SOC Team" escalation (Purple dotted arrow)
- Include small Slack icons for each channel
- Add "Email Notifications" box for all severities (Blue thin arrow)
- Show "Webhook Integration" for external systems (Gray arrow)

**Alert Configuration Details:**

- Small text box showing:
  - "Group by: alertname, cluster, service"
  - "Group wait: 10s"
  - "Repeat interval: 1h"
  - "Inhibit rules: Critical > Warning"

**B. LOGS (Center-Left)**

- Container color: Orange
- Title: "LOGS"
- Components listed vertically:
  - **Loki Distributed** (Log Storage & Querying)
  - **Promtail** (Log Collection DaemonSet)
  - **Application Logs** (Pod stdout/stderr)
  - **System Logs** (Kubernetes events)
- Data flow arrow pointing up to Grafana
- Label: "Log Aggregation & Search"

**C. TRACES (Center-Right)**

- Container color: Purple
- Title: "TRACES"
- Components listed vertically:
  - **Jaeger** (Distributed Tracing Backend)
  - **OpenTelemetry Collector** (Trace Collection)
  - **Distributed Tracing** (Request flows)
  - **Service Maps** (Dependency visualization)
- Data flow arrow pointing up to Grafana
- Label: "Request Tracing & Performance"

**D. SECURITY (Right)**

- Container color: Red
- Title: "SECURITY"
- Components listed vertically:
  - OpenSearch
  - Security Lake
  - OCSF Data
  - SIEM Analytics
- Data flow arrow pointing up to Grafana

### **3. Third Layer - Data Sources**

Create a row of data source boxes below each pillar:

**Under METRICS:**

- "EKS Cluster Metrics"
- "Application Metrics"
- "Infrastructure Metrics"

**Under LOGS:**

- "Pod Logs"
- "System Logs"
- "Audit Logs"

**Under TRACES:**

- "HTTP Requests"
- "Database Calls"
- "Service Calls"

**Under SECURITY:**

- "CloudTrail"
- "VPC Flow Logs"
- "Security Hub"
- "Route53 Logs"

### **4. Bottom Layer - Cross-Account Integration**

- Large container spanning the full width
- Title: "Cross-Account Security Integration"
- Two boxes connected with bidirectional arrow:
  - Left: "Workload Account (EKS)" - Blue color
  - Right: "Security Account (OpenSearch)" - Red color
- Arrow labeled: "IAM Cross-Account Roles"

### **5. Data Flow Arrows:**

- **Upward arrows** from data sources to pillars (green)
- **Upward arrows** from pillars to Grafana (blue)
- **Horizontal arrow** between accounts (orange)
- **Curved arrows** showing data correlation between pillars (dotted lines)

### **6. Additional Elements:**

**Namespace Labels:**

- Add small labels showing:
  - "monitoring/" namespace for Prometheus, Grafana, Loki
  - "observability/" namespace for Jaeger, OTel
  - "Security Account" for OpenSearch

**Technology Icons:**

- Include recognizable icons for: Kubernetes, Prometheus, Grafana, Loki, Jaeger, OpenSearch, AWS
- Use official logos where possible

**Data Flow Indicators:**

- Add small data flow indicators showing:
  - "15-day retention" near Prometheus
  - "90-day retention" near Loki
  - "365-day retention" near Security Lake
  - "Real-time" labels on arrows

**Performance Metrics:**

- Add small performance indicators:
  - "< 5s query response"
  - "< 30s ingestion lag"
  - "99.9% uptime"

### **7. Legend/Key (Bottom Right):**

Create a small legend box showing:

- Green arrow: "Metrics Flow"
- Blue arrow: "Data Integration"
- Orange arrow: "Cross-Account Access"
- Dotted line: "Data Correlation"
- **Red arrow (thick)**: "Critical Alerts"
- **Orange arrow (medium)**: "Warning Alerts"
- **Purple arrow (thick)**: "Security Alerts"
- **Red dotted arrow**: "PagerDuty Escalation"
- **Blue thin arrow**: "Email Notifications"

### **8. Title and Annotations:**

- **Main Title**: "Production EKS Observability Architecture"
- **Subtitle**: "Unified Monitoring, Logging, Tracing & Security Analytics"
- **Footer**: "Enterprise-Grade | High Availability | Cross-Account Security"

## **Technical Specifications:**

- **Resolution**: 1920x1080 or higher
- **Format**: PNG or SVG
- **Text**: Use clear, readable fonts (Arial or similar)
- **Spacing**: Ensure adequate white space between components
- **Alignment**: All elements should be properly aligned and balanced

## **Visual Style Guidelines:**

- Use consistent rounded corners on all containers
- Apply subtle drop shadows for depth
- Use consistent icon sizes
- Maintain proper visual hierarchy with font sizes
- Include subtle gradients in container backgrounds
- Use consistent line weights for arrows and borders

---

**Additional Context for AI:**
This diagram represents a production Kubernetes observability stack that combines traditional monitoring (metrics, logs, traces) with security analytics. The key innovation is the unified Grafana interface that provides a single pane of glass for all observability data, including security events from AWS Security Lake in OCSF format. The cross-account integration allows secure access to centralized security data while maintaining separation of concerns between workload and security accounts.

---

## 🎯 Alternative Simplified Prompt

If the above is too complex, use this shorter version:

**"Create a modern architecture diagram showing a unified observability platform with:**

- **Top**: Grafana dashboard as single pane of glass
- **Middle**: Four pillars - Metrics (Prometheus), Logs (Loki), Traces (Jaeger), Security (OpenSearch)
- **Bottom**: Data sources feeding into each pillar
- **Cross-account**: Show connection between EKS workload account and security account
- **Style**: Professional, clean, enterprise-grade with blue/green color scheme
- **Include**: Data flow arrows, technology icons, and performance metrics"

## 📝 Usage Instructions

1. Copy the main prompt above
2. Paste it into ChatGPT, Claude, or your preferred AI tool
3. Ask for modifications if needed (colors, layout, specific elements)
4. Request different formats (PNG, SVG, etc.) as needed
5. Ask for variations (simplified, detailed, different orientations)

## 🔄 Prompt Variations

**For a simplified version:**
"Make it simpler with fewer details but keep the four pillars concept"

**For a technical version:**
"Add more technical details like port numbers, protocols, and specific configurations"

**For a presentation version:**
"Make it suitable for executive presentation with less technical detail"

**For a dark theme:**
"Use a dark background with light text and neon accent colors"
