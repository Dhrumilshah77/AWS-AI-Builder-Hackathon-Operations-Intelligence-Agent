terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.37.1"
    }
  }
}

provider "coder" {}
provider "kubernetes" {}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for workspaces"
  default     = "coder"
}

variable "pulumi_access_token" {
  type        = string
  description = "Pulumi MCP bearer token for infrastructure automation"
  sensitive   = true
  default     = "pul-xxxx-xxx-xxxx"
}

variable "launchdarkly_access_token" {
  type        = string
  description = "LaunchDarkly MCP API Key for feature flag management"
  sensitive   = true
  default     = "api-xxxx-xxx-xxxx"
}

variable "anthropic_model" {
  type        = string
  description = "The AWS Inference profile ID of the Anthropic model"
  default     = "us.anthropic.claude-sonnet-4-20250514-v1:0"
}

# AI Prompt Parameter - Document Intelligence Focus
data "coder_parameter" "ai_prompt" {
  type        = "string"
  name        = "AI Prompt"
  icon        = "/emojis/1f4c4.png"
  description = "Task prompt for Claude to build document intelligence capabilities"
  default     = "Build a Document Intelligence Workflow using LlamaIndex for PDF extraction, Knowledge Base integration, and multi-agent orchestration with Pulumi infrastructure"
  mutable     = false
}

data "coder_parameter" "cpu" {
  name        = "CPU cores"
  type        = "number"
  description = "CPU cores for workspace"
  default     = 4
  mutable     = true
}

data "coder_parameter" "memory" {
  name        = "Memory (GB)"
  type        = "number"
  description = "Memory in GB for workspace"
  default     = 8
  mutable     = true
}

data "coder_parameter" "disk_size" {
  name        = "Disk size (GB)"
  type        = "number"
  description = "Persistent storage size"
  default     = 30
  mutable     = true
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
  home_folder = "/home/coder"
  port        = 3000
  domain      = element(split("/", data.coder_workspace.me.access_url), 2)

  task_prompt = join(" ", [
    "First, report an initial task to Coder to show you have started!",
    "Then, ${data.coder_parameter.ai_prompt.value}.",
  ])

  system_prompt = <<-EOT
    You are a Document Intelligence specialist with access to Pulumi and LaunchDarkly MCP servers.
    Use Pulumi for deploying document processing infrastructure and LaunchDarkly for feature flags.
    Build LlamaIndex Workflows for extracting structured data from PDFs (orders, invoices, catalogs).
    Implement Knowledge Base queries with specialist agents for each document type.
    Report all tasks to Coder following the guidelines.
  EOT
}

resource "coder_agent" "dev" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e

    # Install dependencies for document intelligence
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip nodejs npm poppler-utils

    # Install LlamaIndex and document processing packages
    pip3 install llama-index llama-cloud boto3 pydantic pypdf openai

    # Setup workspace
    echo "Document Intelligence Workspace ready with Pulumi and LaunchDarkly MCP"
  EOT

  metadata {
    display_name = "CPU Usage"
    key          = "cpu"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage"
    key          = "mem"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
}

# Claude Code Module with Pulumi and LaunchDarkly MCP Servers
module "claude-code" {
  count         = data.coder_workspace.me.start_count
  source        = "registry.coder.com/coder/claude-code/coder"
  version       = "4.7.1"
  model         = var.anthropic_model
  agent_id      = coder_agent.dev.id
  workdir       = local.home_folder
  subdomain     = false
  ai_prompt     = local.task_prompt
  system_prompt = local.system_prompt
  report_tasks  = true

  mcp = <<-EOF
  {
    "mcpServers": {
      "pulumi": {
        "headers": {
          "Authorization": "Bearer ${var.pulumi_access_token}"
        },
        "type": "http",
        "url": "https://mcp.ai.pulumi.com/mcp"
      },
      "LaunchDarkly": {
        "command": "npx",
        "args": [
          "-y", "--package", "@launchdarkly/mcp-server", "--", "mcp", "start",
          "--api-key", "${var.launchdarkly_access_token}"
        ]
      }
    }
  }
  EOF
}

# AI Task Resource for Evaluation
resource "coder_ai_task" "claude-code" {
  count = data.coder_workspace.me.start_count
  sidebar_app {
    id = module.claude-code[0].task_app_id
  }
}

# Document Intelligence Web App
resource "coder_app" "docintel" {
  agent_id     = coder_agent.dev.id
  slug         = "docintel"
  display_name = "Document Intelligence"
  icon         = "/icon/code.svg"
  url          = "http://localhost:${local.port}"
  subdomain    = true

  healthcheck {
    url       = "http://localhost:${local.port}"
    interval  = 5
    threshold = 3
  }
}

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-home"
    namespace = var.namespace
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.disk_size.value}Gi"
      }
    }
  }
}

resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count

  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "docintel-pulumi-ld-${lower(data.coder_workspace.me.name)}"
    }
  }

  spec {
    container {
      name    = "dev"
      image   = "codercom/enterprise-base:ubuntu"
      command = ["sh", "-c", coder_agent.dev.init_script]

      resources {
        requests = {
          cpu    = "${data.coder_parameter.cpu.value}"
          memory = "${data.coder_parameter.memory.value}Gi"
        }
        limits = {
          cpu    = "${data.coder_parameter.cpu.value}"
          memory = "${data.coder_parameter.memory.value}Gi"
        }
      }

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.dev.token
      }

      volume_mount {
        mount_path = local.home_folder
        name       = "home"
        read_only  = false
      }
    }

    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
        read_only  = false
      }
    }
  }
}
