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

variable "arize_space_key" {
  type        = string
  description = "Arize Space Key for AI observability tracing"
  sensitive   = true
  default     = "xxxx-xxx-xxxx"
}

variable "arize_api_key" {
  type        = string
  description = "Arize API Key for MCP server"
  sensitive   = true
  default     = "xxxx-xxx-xxxx"
}

variable "openai_api_key" {
  type        = string
  description = "OpenAI API Key for LlamaIndex embeddings"
  sensitive   = true
  default     = "sk-xxxx-xxx-xxxx"
}

variable "anthropic_model" {
  type        = string
  description = "The AWS Inference profile ID of the Anthropic model"
  default     = "us.anthropic.claude-sonnet-4-20250514-v1:0"
}

# AI Prompt Parameter - Document Intelligence with Observability
data "coder_parameter" "ai_prompt" {
  type        = "string"
  name        = "AI Prompt"
  icon        = "/emojis/1f50d.png"
  description = "Task prompt for Claude to build document intelligence with observability"
  default     = "Build a Document Intelligence Agent using LlamaIndex Workflow for structured PDF extraction with Arize observability tracing and Knowledge Base integration"
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
    You are a Document Intelligence specialist with access to Arize and LlamaIndex MCP servers.
    Use Arize for AI observability, tracing spans, and monitoring document extraction performance.
    Use LlamaIndex for building RAG pipelines and document intelligence workflows.
    Extract structured data from PDFs using LlamaExtract with Pydantic schemas.
    Build specialist agents for Orders, Invoices, and Catalog knowledge bases.
    Report all tasks to Coder following the guidelines.
  EOT
}

resource "coder_agent" "dev" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e

    # Install dependencies for document intelligence with observability
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip nodejs npm poppler-utils

    # Install Arize, LlamaIndex, and document processing packages
    pip3 install arize llama-index llama-cloud opentelemetry-api opentelemetry-sdk openinference-instrumentation boto3 pydantic pypdf openai

    # Setup workspace
    echo "Document Intelligence Workspace ready with Arize observability and LlamaIndex MCP"
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

# Claude Code Module with Arize and LlamaIndex MCP Servers
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
      "arize-tracing-assistant": {
        "command": "uvx",
        "args": ["arize-tracing-assistant@latest"],
        "env": {
          "ARIZE_SPACE_KEY": "${var.arize_space_key}",
          "ARIZE_API_KEY": "${var.arize_api_key}"
        }
      },
      "llamaindex": {
        "command": "npx",
        "args": ["-y", "@llamaindex/mcp-server"],
        "env": {
          "OPENAI_API_KEY": "${var.openai_api_key}"
        }
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
      "app.kubernetes.io/instance" = "docintel-arize-llama-${lower(data.coder_workspace.me.name)}"
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

      env {
        name  = "ARIZE_SPACE_KEY"
        value = var.arize_space_key
      }

      env {
        name  = "ARIZE_API_KEY"
        value = var.arize_api_key
      }

      env {
        name  = "OPENAI_API_KEY"
        value = var.openai_api_key
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
