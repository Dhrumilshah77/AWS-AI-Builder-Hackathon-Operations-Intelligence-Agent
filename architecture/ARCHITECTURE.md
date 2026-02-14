# Architecture Diagram

## Operations Intelligence Agent - AWS Services Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                          │
│                        OPERATIONS INTELLIGENCE AGENT PIPELINE                            │
│                                                                                          │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│   DATA INGESTION LAYER                                                                   │
│   ═══════════════════                                                                    │
│                                                                                          │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                                     │
│   │   Orders    │  │  Invoices   │  │  Catalogs   │                                     │
│   │   (PDFs)    │  │   (PDFs)    │  │   (PDFs)    │                                     │
│   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                                     │
│          │                │                │                                             │
│          └────────────────┼────────────────┘                                             │
│                           ▼                                                              │
│          ┌────────────────────────────────┐                                              │
│          │      ☁️  LLAMACLOUD            │                                              │
│          │      LlamaExtract API          │                                              │
│          │   (Pydantic Schema Extraction) │                                              │
│          └────────────────┬───────────────┘                                              │
│                           │                                                              │
│                           ▼                                                              │
│          ┌────────────────────────────────┐                                              │
│          │      📦 AMAZON S3              │                                              │
│          │   Extracted JSON Documents     │                                              │
│          │   docintel-extracted-data/     │                                              │
│          └────────────────┬───────────────┘                                              │
│                           │                                                              │
├───────────────────────────┼─────────────────────────────────────────────────────────────┤
│                           │                                                              │
│   KNOWLEDGE LAYER         │                                                              │
│   ═══════════════         ▼                                                              │
│                                                                                          │
│   ┌──────────────────────────────────────────────────────────────────────┐              │
│   │                    AMAZON BEDROCK KNOWLEDGE BASES                     │              │
│   │                                                                       │              │
│   │  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐         │              │
│   │  │   📋 ORDERS     │ │  📄 INVOICES    │ │  📚 CATALOGS    │         │              │
│   │  │   KB: Q4GFS0U7K5│ │  KB: KWI74777TX │ │  KB: MOXOMDZFCP │         │              │
│   │  │   4 Documents   │ │   4 Documents   │ │   2 Documents   │         │              │
│   │  └────────┬────────┘ └────────┬────────┘ └────────┬────────┘         │              │
│   │           │                   │                   │                  │              │
│   │           └───────────────────┼───────────────────┘                  │              │
│   │                               ▼                                      │              │
│   │              ┌────────────────────────────────┐                      │              │
│   │              │  🔍 OPENSEARCH SERVERLESS      │                      │              │
│   │              │     Vector Embeddings          │                      │              │
│   │              │     Semantic Search            │                      │              │
│   │              └────────────────────────────────┘                      │              │
│   └──────────────────────────────────────────────────────────────────────┘              │
│                                                                                          │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│   AGENT LAYER                                                                            │
│   ═══════════                                                                            │
│                                                                                          │
│   ┌──────────────────────────────────────────────────────────────────────┐              │
│   │                    AMAZON BEDROCK AGENTCORE                          │              │
│   │                                                                       │              │
│   │  ┌─────────────────────────────────────────────────────────┐         │              │
│   │  │              🤖 LANGGRAPH AGENT                          │         │              │
│   │  │         DocIntelLangGraphAgent_Agent-d3pm5k8uxh         │         │              │
│   │  │                                                          │         │              │
│   │  │   ┌──────────┐  ┌──────────┐  ┌──────────┐              │         │              │
│   │  │   │  Order   │  │ Invoice  │  │ Catalog  │              │         │              │
│   │  │   │  Agent   │  │  Agent   │  │  Agent   │              │         │              │
│   │  │   │  (Tool)  │  │  (Tool)  │  │  (Tool)  │              │         │              │
│   │  │   └──────────┘  └──────────┘  └──────────┘              │         │              │
│   │  └─────────────────────────────────────────────────────────┘         │              │
│   │                                                                       │              │
│   │                    Powered by: Claude (Bedrock)                       │              │
│   └──────────────────────────────────────────────────────────────────────┘              │
│                                                                                          │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│   PRESENTATION LAYER                                                                     │
│   ══════════════════                                                                     │
│                                                                                          │
│   ┌──────────────────────────────────────────────────────────────────────┐              │
│   │                       🌐 AMAZON CLOUDFRONT                           │              │
│   │                                                                       │              │
│   │              ┌────────────────────────────────┐                       │              │
│   │              │        📦 AMAZON S3            │                       │              │
│   │              │     Static Web Assets          │                       │              │
│   │              │   operations-intelligence.html │                       │              │
│   │              └────────────────────────────────┘                       │              │
│   │                                                                       │              │
│   │   URL: https://dxoecztual878.cloudfront.net/operations-intelligence.html            │
│   └──────────────────────────────────────────────────────────────────────┘              │
│                                                                                          │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│   INFRASTRUCTURE LAYER                                                                   │
│   ════════════════════                                                                   │
│                                                                                          │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                         │
│   │ CloudFormation  │  │   IAM Roles     │  │   CloudWatch    │                         │
│   │  (KB Deploy)    │  │  (Permissions)  │  │  (Observability)│                         │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘                         │
│                                                                                          │
│   ┌─────────────────┐  ┌─────────────────┐                                              │
│   │ Secrets Manager │  │  Coder Templates│                                              │
│   │  (API Keys)     │  │   (IaC)         │                                              │
│   └─────────────────┘  └─────────────────┘                                              │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
1. PDF Documents → LlamaCloud Extract → Structured JSON
2. JSON Data → S3 Upload → Knowledge Base Sync
3. User Query → AgentCore Runtime → Knowledge Base Search
4. Search Results → LangGraph Agent → Formatted Response
5. Response → CloudFront → User Interface
```

## AWS Services Summary

| Layer | Services |
|-------|----------|
| **Ingestion** | S3, Secrets Manager |
| **Knowledge** | Bedrock Knowledge Bases, OpenSearch Serverless |
| **Agent** | Bedrock AgentCore, Bedrock (Claude) |
| **Presentation** | CloudFront, S3 |
| **Infrastructure** | CloudFormation, IAM, CloudWatch |
