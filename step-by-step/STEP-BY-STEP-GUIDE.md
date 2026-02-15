# Step-by-Step Guide: Building the Operations Intelligence Agent

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Architecture Diagram](#2-architecture-diagram)
3. [Workflow Process](#3-workflow-process)
4. [Step 1: Setting Up Infrastructure with CloudFormation](#step-1-setting-up-infrastructure-with-cloudformation)
5. [Step 2: Configuring LlamaCloud for Document Extraction](#step-2-configuring-llamacloud-for-document-extraction)
6. [Step 3: Extracting Data from PDF Documents](#step-3-extracting-data-from-pdf-documents)
7. [Step 4: Creating Amazon Bedrock Knowledge Bases](#step-4-creating-amazon-bedrock-knowledge-bases)
8. [Step 5: Syncing Knowledge Bases with Extracted Data](#step-5-syncing-knowledge-bases-with-extracted-data)
9. [Step 6: Building the LangGraph Agent](#step-6-building-the-langgraph-agent)
10. [Step 7: Deploying to Amazon Bedrock AgentCore](#step-7-deploying-to-amazon-bedrock-agentcore)
11. [Step 8: Creating the Web Interface](#step-8-creating-the-web-interface)
12. [Step 9: Deploying to Amazon CloudFront](#step-9-deploying-to-amazon-cloudfront)
13. [Step 10: Creating Coder Templates](#step-10-creating-coder-templates)
14. [Tools and Services Summary](#tools-and-services-summary)

---

## 1. Project Overview

### What We Built
We built an **Operations Intelligence Agent** - a smart system that can read business documents (like orders, invoices, and product catalogs), understand them, and answer questions about them.

### Why This Project is Helpful
Imagine you have thousands of PDF documents - orders from customers, invoices from suppliers, product catalogs. Finding specific information manually would take hours. This system:
- **Automatically reads** PDF documents
- **Extracts important data** (customer names, order totals, product prices)
- **Stores it in a searchable format**
- **Answers questions** like "What did Jane Doe order?" or "Show invoices from AnyCompany"

### The Problem We Solved
Business documents are messy and unstructured. This project converts them into organized, queryable data that anyone can search using natural language.

---

## 2. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                      │
│                    OPERATIONS INTELLIGENCE AGENT - FULL ARCHITECTURE                 │
│                                                                                      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   STEP 1: DOCUMENT INPUT                                                             │
│   ══════════════════════                                                             │
│                                                                                      │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                             │
│   │  📄 Orders  │    │ 📄 Invoices │    │ 📄 Catalogs │                             │
│   │   (PDFs)    │    │   (PDFs)    │    │   (PDFs)    │                             │
│   │   4 files   │    │   4 files   │    │   2 files   │                             │
│   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                             │
│          │                  │                  │                                     │
│          └──────────────────┼──────────────────┘                                     │
│                             │                                                        │
│                             ▼                                                        │
│   ┌─────────────────────────────────────────────────────────────────────┐           │
│   │                    📦 AMAZON S3 BUCKET                               │           │
│   │                    (Raw Document Storage)                            │           │
│   │                    pet-store-data-extraction/                        │           │
│   └─────────────────────────────┬───────────────────────────────────────┘           │
│                                 │                                                    │
├─────────────────────────────────┼────────────────────────────────────────────────────┤
│                                 │                                                    │
│   STEP 2: DOCUMENT EXTRACTION   │                                                    │
│   ═══════════════════════════   ▼                                                    │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────┐           │
│   │                    ☁️  LLAMACLOUD EXTRACT API                        │           │
│   │                                                                      │           │
│   │    What it does:                                                     │           │
│   │    • Reads PDF files using AI                                        │           │
│   │    • Understands document structure                                  │           │
│   │    • Extracts data into organized JSON format                        │           │
│   │                                                                      │           │
│   │    Uses Pydantic Schemas to define:                                  │           │
│   │    • Order: order_id, customer_name, items[], total                  │           │
│   │    • Invoice: invoice_id, supplier_name, items[], total              │           │
│   │    • Catalog: catalog_period, products[]                             │           │
│   └─────────────────────────────┬───────────────────────────────────────┘           │
│                                 │                                                    │
│                                 ▼                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐           │
│   │                    📦 AMAZON S3 BUCKET                               │           │
│   │                    (Extracted JSON Storage)                          │           │
│   │                    knowledge-base-data/orders/                       │           │
│   │                    knowledge-base-data/invoices/                     │           │
│   │                    knowledge-base-data/catalogs/                     │           │
│   └─────────────────────────────┬───────────────────────────────────────┘           │
│                                 │                                                    │
├─────────────────────────────────┼────────────────────────────────────────────────────┤
│                                 │                                                    │
│   STEP 3: KNOWLEDGE STORAGE     │                                                    │
│   ═════════════════════════     ▼                                                    │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────┐           │
│   │              AMAZON BEDROCK KNOWLEDGE BASES                          │           │
│   │                                                                      │           │
│   │   What it does:                                                      │           │
│   │   • Converts text into "embeddings" (numerical representations)      │           │
│   │   • Stores embeddings in vector database                             │           │
│   │   • Enables semantic search (find by meaning, not exact words)       │           │
│   │                                                                      │           │
│   │   ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐        │           │
│   │   │   📋 ORDERS KB  │ │  📄 INVOICES KB │ │  📚 CATALOGS KB │        │           │
│   │   │   ID: Q4GFS0U7K5│ │  ID: KWI74777TX │ │  ID: MOXOMDZFCP │        │           │
│   │   │   4 documents   │ │   4 documents   │ │   2 documents   │        │           │
│   │   └────────┬────────┘ └────────┬────────┘ └────────┬────────┘        │           │
│   │            │                   │                   │                 │           │
│   │            └───────────────────┼───────────────────┘                 │           │
│   │                                │                                     │           │
│   │                                ▼                                     │           │
│   │            ┌───────────────────────────────────────┐                 │           │
│   │            │    🔍 AMAZON OPENSEARCH SERVERLESS    │                 │           │
│   │            │         (Vector Database)             │                 │           │
│   │            │    Stores embeddings for fast search  │                 │           │
│   │            └───────────────────────────────────────┘                 │           │
│   └─────────────────────────────────────────────────────────────────────┘           │
│                                                                                      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   STEP 4: AGENT LAYER                                                                │
│   ═══════════════════                                                                │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────┐           │
│   │                    AMAZON BEDROCK AGENTCORE                          │           │
│   │                                                                      │           │
│   │   What it does:                                                      │           │
│   │   • Hosts AI agents in the cloud                                     │           │
│   │   • Manages agent execution and scaling                              │           │
│   │   • Provides API endpoint for queries                                │           │
│   │                                                                      │           │
│   │   ┌─────────────────────────────────────────────────────────┐        │           │
│   │   │              🤖 LANGGRAPH AGENT                          │        │           │
│   │   │         DocIntelLangGraphAgent_Agent-d3pm5k8uxh         │        │           │
│   │   │                                                          │        │           │
│   │   │   How it works:                                          │        │           │
│   │   │   1. Receives user question                              │        │           │
│   │   │   2. Decides which Knowledge Base to query               │        │           │
│   │   │   3. Retrieves relevant information                      │        │           │
│   │   │   4. Generates human-readable answer                     │        │           │
│   │   │                                                          │        │           │
│   │   │   ┌──────────┐  ┌──────────┐  ┌──────────┐              │        │           │
│   │   │   │  Order   │  │ Invoice  │  │ Catalog  │              │        │           │
│   │   │   │  Tool    │  │   Tool   │  │   Tool   │              │        │           │
│   │   │   └──────────┘  └──────────┘  └──────────┘              │        │           │
│   │   └─────────────────────────────────────────────────────────┘        │           │
│   │                                                                      │           │
│   │                    Powered by: Claude (Amazon Bedrock)               │           │
│   └─────────────────────────────────────────────────────────────────────┘           │
│                                                                                      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   STEP 5: USER INTERFACE                                                             │
│   ══════════════════════                                                             │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────┐           │
│   │                       🌐 AMAZON CLOUDFRONT                           │           │
│   │                          (Content Delivery Network)                  │           │
│   │                                                                      │           │
│   │   What it does:                                                      │           │
│   │   • Serves web pages globally with low latency                       │           │
│   │   • Caches content at edge locations                                 │           │
│   │   • Provides HTTPS security                                          │           │
│   │                                                                      │           │
│   │              ┌────────────────────────────────────┐                  │           │
│   │              │        📦 AMAZON S3                │                  │           │
│   │              │     (Static Website Hosting)       │                  │           │
│   │              │   operations-intelligence.html     │                  │           │
│   │              └────────────────────────────────────┘                  │           │
│   │                                                                      │           │
│   │   URL: https://dxoecztual878.cloudfront.net/operations-intelligence.html        │
│   └─────────────────────────────────────────────────────────────────────┘           │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Workflow Process

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  PDF    │───▶│ Extract │───▶│  Store  │───▶│  Query  │───▶│ Display │
│ Docs    │    │  Data   │    │   in KB │    │  Agent  │    │ Results │
└─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘
     │              │              │              │              │
     │              │              │              │              │
     ▼              ▼              ▼              ▼              ▼
   S3 Raw      LlamaCloud     Bedrock KB     AgentCore     CloudFront
   Storage      Extract       + OpenSearch   + LangGraph   Web UI
```

---

## Step 1: Setting Up Infrastructure with CloudFormation

### What is AWS CloudFormation?
CloudFormation is AWS's "Infrastructure as Code" service. Instead of clicking through the AWS console to create resources, you write a YAML file that describes what you want, and CloudFormation creates everything automatically.

### Why We Used It
We needed to create multiple resources (Knowledge Bases, S3 buckets, IAM roles) that work together. CloudFormation ensures they're all created correctly and connected properly.

### What We Did
```bash
# Downloaded the CloudFormation template
aws s3 cp s3://ws-assets-prod-iad-r-pdx-f3b3f9f1a7d6a3d0/5aae1f81-dfec-481c-b066-8f80bc459307/llamaindex_document_extraction_kbs.yaml .

# Deployed the stack
aws cloudformation create-stack \
  --stack-name docintel-knowledge-bases \
  --template-body file://llamaindex_document_extraction_kbs.yaml \
  --capabilities CAPABILITY_IAM
```

### What Got Created
- 3 Knowledge Bases (Orders, Invoices, Catalogs)
- S3 bucket for storing documents
- IAM roles for permissions
- OpenSearch Serverless collections for vector storage

---

## Step 2: Configuring LlamaCloud for Document Extraction

### What is LlamaCloud?
LlamaCloud is a service from LlamaIndex that provides AI-powered document processing. It can read PDFs, understand their structure, and extract specific information you define.

### Why We Used It
PDF documents are "unstructured" - they're designed for humans to read, not computers. LlamaCloud's Extract API uses AI to understand documents like a human would, pulling out exactly the data we need.

### What We Did
```bash
# Stored API credentials securely in AWS Secrets Manager
aws secretsmanager create-secret \
  --name partner-llamaindex-api-key \
  --secret-string "your-api-key-here"

aws secretsmanager create-secret \
  --name partner-llamaindex-org-id \
  --secret-string "your-org-id-here"
```

### How It Connects
- Credentials stored in AWS Secrets Manager (secure)
- Python script retrieves credentials at runtime
- LlamaCloud API is called to process documents

---

## Step 3: Extracting Data from PDF Documents

### What is Pydantic?
Pydantic is a Python library for defining data structures. We use it to tell LlamaCloud exactly what information to extract from each document type.

### Why We Used It
Different documents have different information. An order has customer names and items. An invoice has supplier names and totals. Pydantic schemas define these structures clearly.

### What We Did

**Defined schemas for each document type:**

```python
# Order Schema - what to extract from order PDFs
class Order(BaseModel):
    order_id: str           # e.g., "ORD-2024-001234"
    order_date: str         # e.g., "2024-01-14"
    customer_name: str      # e.g., "Jane Doe"
    customer_email: str     # e.g., "jane@example.com"
    items: List[OrderItem]  # List of products ordered
    subtotal: float         # Before tax
    tax: float              # Tax amount
    total: float            # Final total

# Invoice Schema - what to extract from invoice PDFs
class Invoice(BaseModel):
    invoice_id: str         # e.g., "INV-2024-5678"
    invoice_date: str       # e.g., "2024-01-10"
    supplier_name: str      # e.g., "AnyCompany Pet Supplies"
    payment_terms: str      # e.g., "Net 30"
    items: List[InvoiceItem]
    total: float

# Catalog Schema - what to extract from catalog PDFs
class Catalog(BaseModel):
    catalog_period: str     # e.g., "Q1 2024"
    products: List[CatalogProduct]  # All products in catalog
```

**Extraction process:**

```python
# For each PDF document:
# 1. Upload to LlamaCloud
uploaded = llama_client.files.create(file=pdf_file, purpose='extract')

# 2. Extract using our schema
result = llama_client.extraction.extract(
    file_id=uploaded.id,
    data_schema=Order.model_json_schema(),  # Tell it what to extract
    config={"extraction_mode": "BALANCED"}
)

# 3. Get structured JSON data
extracted_data = result.data
```

### Results
- **10 documents processed** (4 orders, 4 invoices, 2 catalogs)
- Each converted from messy PDF to clean JSON
- Uploaded to S3 for Knowledge Base ingestion

---

## Step 4: Creating Amazon Bedrock Knowledge Bases

### What is Amazon Bedrock Knowledge Base?
A Knowledge Base is a managed service that:
1. Takes your documents
2. Breaks them into chunks
3. Converts text to "embeddings" (numerical representations)
4. Stores them in a vector database
5. Enables semantic search

### What is Semantic Search?
Traditional search finds exact word matches. Semantic search understands meaning.
- Search "customer orders" → finds documents about "client purchases" too
- Search "payment" → finds documents about "invoices" and "transactions"

### Why We Used It
We wanted users to ask questions in natural language and get accurate answers, even if they don't use the exact words in the documents.

### Knowledge Bases Created

| Knowledge Base | ID | Documents | Purpose |
|----------------|-----|-----------|---------|
| Orders KB | Q4GFS0U7K5 | 4 | Customer order information |
| Invoices KB | KWI74777TX | 4 | Supplier invoice data |
| Catalogs KB | MOXOMDZFCP | 2 | Product catalog listings |

### How It Works
```
User asks: "What did Jane order?"
                    │
                    ▼
        ┌───────────────────┐
        │  Convert question │
        │  to embedding     │
        └─────────┬─────────┘
                  │
                  ▼
        ┌───────────────────┐
        │ Search vector DB  │
        │ for similar       │
        │ embeddings        │
        └─────────┬─────────┘
                  │
                  ▼
        ┌───────────────────┐
        │ Return matching   │
        │ document chunks   │
        └───────────────────┘
```

---

## Step 5: Syncing Knowledge Bases with Extracted Data

### What is Syncing?
After uploading extracted JSON files to S3, we need to tell each Knowledge Base to "ingest" (process and index) these new documents.

### Why We Did It
Knowledge Bases don't automatically detect new files. We must trigger a sync to:
1. Read new files from S3
2. Create embeddings
3. Store in vector database

### What We Did
```bash
# Sync Orders Knowledge Base
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id Q4GFS0U7K5 \
  --data-source-id <orders-data-source-id>

# Sync Invoices Knowledge Base
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id KWI74777TX \
  --data-source-id <invoices-data-source-id>

# Sync Catalogs Knowledge Base
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id MOXOMDZFCP \
  --data-source-id <catalogs-data-source-id>
```

### Verification
```bash
# Check sync status
aws bedrock-agent get-ingestion-job \
  --knowledge-base-id Q4GFS0U7K5 \
  --ingestion-job-id <job-id>

# Status: COMPLETE means documents are searchable
```

---

## Step 6: Building the LangGraph Agent

### What is LangGraph?
LangGraph is a framework for building AI agents that can:
- Make decisions
- Use tools
- Follow multi-step processes
- Maintain conversation state

### What is an AI Agent?
An agent is more than a chatbot. It can:
1. Understand your question
2. Decide which tool to use
3. Execute actions
4. Combine results
5. Give you a final answer

### Why We Used It
We needed an intelligent system that could:
- Understand which Knowledge Base to query (orders, invoices, or catalogs)
- Execute the search
- Format results nicely

### Agent Code Structure
```python
from langchain.agents import create_agent
from langchain.tools import tool

# Define tools the agent can use
@tool
def query_orders(order_id: str = None) -> dict:
    """Query the Orders Knowledge Base"""
    # Search for order information
    return search_results

@tool
def query_invoices(supplier: str = None) -> dict:
    """Query the Invoices Knowledge Base"""
    # Search for invoice information
    return search_results

@tool
def query_catalogs(period: str = None) -> dict:
    """Query the Catalogs Knowledge Base"""
    # Search for catalog information
    return search_results

# Create the agent with tools
agent = Agent(
    system_prompt="You are a Document Intelligence Agent...",
    tools=[query_orders, query_invoices, query_catalogs]
)
```

### How the Agent Decides

```
User: "What invoices are from AnyCompany?"
                    │
                    ▼
        ┌───────────────────────┐
        │ Agent thinks:         │
        │ "This is about        │
        │  invoices and a       │
        │  supplier name"       │
        └───────────┬───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Agent decides:        │
        │ "Use query_invoices   │
        │  tool with supplier   │
        │  = 'AnyCompany'"      │
        └───────────┬───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Tool executes:        │
        │ Searches Invoices KB  │
        │ Returns matching data │
        └───────────┬───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Agent formats:        │
        │ Creates nice response │
        │ with invoice details  │
        └───────────────────────┘
```

---

## Step 7: Deploying to Amazon Bedrock AgentCore

### What is Amazon Bedrock AgentCore?
AgentCore is a managed service for deploying AI agents. It handles:
- Hosting your agent code
- Scaling up/down based on demand
- Providing an API endpoint
- Logging and monitoring

### Why We Used It
Instead of managing servers ourselves, AgentCore:
- Runs our agent in the cloud
- Handles all infrastructure
- Provides easy invocation via API

### Deployment Steps
```bash
# 1. Create agent project
agentcore create -p DocIntelLangGraphAgent \
  --agent-framework LangChain_LangGraph \
  --model-provider Bedrock

# 2. Deploy to cloud
agentcore deploy --auto-update-on-conflict

# Output:
# ✅ Agent created: DocIntelLangGraphAgent_Agent-d3pm5k8uxh
# Agent ARN: arn:aws:bedrock-agentcore:us-west-2:476998156360:runtime/...
```

### Testing the Agent
```bash
# Invoke the deployed agent
agentcore invoke '{"prompt": "What orders does Jane Doe have?"}'

# Response: Details about Jane Doe's orders
```

---

## Step 8: Creating the Web Interface

### What We Built
An interactive dashboard where users can:
- Click agent badges to view data by type
- Type questions in natural language
- See results in formatted tables (not raw JSON)

### Why We Built It
A command-line interface isn't user-friendly. A web interface lets anyone:
- Use the system without technical knowledge
- See data in an organized way
- Try different queries easily

### Key Features

**1. Agent Badges (Clickable)**
```html
<span class="agent-badge orders" onclick="showAgentData('orders')">
  Order Agent
</span>
<span class="agent-badge invoices" onclick="showAgentData('invoices')">
  Invoice Agent
</span>
<span class="agent-badge catalogs" onclick="showAgentData('catalogs')">
  Catalog Agent
</span>
```

**2. Tabular Results Display**
```javascript
function displayOrdersTable(orders, title) {
    let html = `
        <table class="data-table">
            <thead>
                <tr>
                    <th>Order ID</th>
                    <th>Date</th>
                    <th>Customer</th>
                    <th>Total</th>
                </tr>
            </thead>
            <tbody>
    `;
    // ... generate table rows
}
```

**3. Query Processing**
```javascript
function processQuery(query) {
    if (query.includes('order')) {
        return queryOrdersKB();
    } else if (query.includes('invoice')) {
        return queryInvoicesKB();
    } else if (query.includes('catalog')) {
        return queryCatalogsKB();
    }
}
```

---

## Step 9: Deploying to Amazon CloudFront

### What is Amazon CloudFront?
CloudFront is a Content Delivery Network (CDN). It:
- Caches your website at locations worldwide
- Serves content from the nearest location to users
- Provides HTTPS security
- Handles high traffic

### Why We Used It
- **Fast loading**: Content served from edge locations
- **Reliable**: AWS manages availability
- **Secure**: HTTPS by default

### Deployment Steps
```bash
# 1. Upload HTML to S3
aws s3 cp index.html s3://bucket-name/website/operations-intelligence.html \
  --content-type "text/html"

# 2. Invalidate CloudFront cache (to show new version)
aws cloudfront create-invalidation \
  --distribution-id E1F62XXHKNGIDX \
  --paths "/operations-intelligence.html"
```

### Final URL
**https://dxoecztual878.cloudfront.net/operations-intelligence.html**

---

## Step 10: Creating Coder Templates

### What are Coder Templates?
Coder templates are Infrastructure-as-Code (Terraform) files that define reproducible development environments with AI coding assistants.

### Why We Created Them
- **Reproducibility**: Anyone can spin up the same environment
- **Standardization**: Consistent setup across team
- **AI Integration**: Built-in Claude Code with MCP servers

### Templates Created

**1. docintel-workflow-pulumi-ld**
- **MCP Servers**: Pulumi + LaunchDarkly
- **Purpose**: Infrastructure automation with feature flags
- **Use Case**: Deploy and manage cloud resources with AI assistance

**2. docintel-workflow-arize-llama**
- **MCP Servers**: Arize + LlamaIndex
- **Purpose**: AI observability and RAG pipelines
- **Use Case**: Monitor agent performance and build document pipelines

### Template Structure
```hcl
# Terraform configuration
module "claude-code" {
  source = "registry.coder.com/coder/claude-code/coder"

  # MCP Server configuration
  mcp = {
    "mcpServers": {
      "pulumi": {
        "url": "https://mcp.ai.pulumi.com/mcp"
      },
      "LaunchDarkly": {
        "command": "npx",
        "args": ["@launchdarkly/mcp-server"]
      }
    }
  }
}
```

---

## Tools and Services Summary

| Tool/Service | Category | What It Does | Why We Used It |
|-------------|----------|--------------|----------------|
| **Amazon S3** | Storage | Stores files in the cloud | Reliable, scalable document storage |
| **AWS Secrets Manager** | Security | Stores API keys securely | Keep credentials safe, not in code |
| **AWS CloudFormation** | Infrastructure | Creates AWS resources from YAML | Automated, repeatable setup |
| **LlamaCloud Extract** | AI/Document | Extracts data from PDFs | Converts unstructured to structured |
| **Pydantic** | Python Library | Defines data structures | Clear schemas for extraction |
| **Amazon Bedrock** | AI Platform | Hosts AI models | Powers Claude for responses |
| **Amazon Bedrock KB** | Knowledge Management | Semantic search over documents | Find info by meaning |
| **OpenSearch Serverless** | Database | Vector storage | Fast similarity search |
| **LangGraph** | Agent Framework | Builds AI agents | Multi-step reasoning |
| **AgentCore** | Agent Runtime | Hosts agents in cloud | Managed deployment |
| **Amazon CloudFront** | CDN | Delivers web content | Fast, global access |
| **Coder Templates** | DevOps | Reproducible environments | Consistent development |

---

## Quick Reference: Connecting Everything

```
┌─────────────────────────────────────────────────────────────────┐
│                     HOW EVERYTHING CONNECTS                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   [PDF Files]                                                    │
│       │                                                          │
│       │ uploaded to                                              │
│       ▼                                                          │
│   [S3 Bucket] ─────────────────┐                                │
│       │                        │                                 │
│       │ read by                │ provides files to               │
│       ▼                        ▼                                 │
│   [LlamaCloud Extract]    [Bedrock KB]                          │
│       │                        │                                 │
│       │ produces JSON          │ indexed in                      │
│       ▼                        ▼                                 │
│   [S3: extracted/]        [OpenSearch]                          │
│       │                        │                                 │
│       │ synced to              │ searched by                     │
│       ▼                        ▼                                 │
│   [Bedrock KB] ◄──────────[LangGraph Agent]                     │
│                                │                                 │
│                                │ hosted on                       │
│                                ▼                                 │
│                           [AgentCore]                            │
│                                │                                 │
│                                │ called by                       │
│                                ▼                                 │
│                           [Web Interface]                        │
│                                │                                 │
│                                │ served by                       │
│                                ▼                                 │
│                           [CloudFront]                           │
│                                │                                 │
│                                │ accessed by                     │
│                                ▼                                 │
│                           [End User]                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Conclusion

This project demonstrates how to build an end-to-end document intelligence system using AWS services and AI. By following these steps, you can:

1. **Extract** structured data from any PDF documents
2. **Store** and **index** data for semantic search
3. **Build** intelligent agents that answer natural language questions
4. **Deploy** user-friendly web interfaces

The same pattern can be applied to any document-heavy workflow: legal documents, medical records, financial reports, or technical manuals.

---

*Built for AWS AI Builder Hackathon - Clash of Agents Challenge*
