#!/usr/bin/env python3
"""
Process documents with LlamaCloud Extract API and prepare for Knowledge Base ingestion.
"""

import os
import json
import boto3
import time
from datetime import datetime
from pydantic import BaseModel, Field
from typing import List, Optional
from llama_cloud import LlamaCloud

# Configuration
S3_BUCKET = "team-databucketforknowledge-c3qkrlx6wk6l"
S3_PREFIX = "pet-store-data-extraction/"

# Get credentials from Secrets Manager
secrets_client = boto3.client('secretsmanager', region_name='us-west-2')

def get_secret(secret_name: str) -> str:
    response = secrets_client.get_secret_value(SecretId=secret_name)
    return response['SecretString']

LLAMACLOUD_API_KEY = get_secret('partner-llamaindex-api-key')
LLAMACLOUD_ORG_ID = get_secret('partner-llamaindex-org-id')

print(f"API Key: {LLAMACLOUD_API_KEY[:20]}...")
print(f"Org ID: {LLAMACLOUD_ORG_ID}")

# Initialize clients
s3_client = boto3.client('s3', region_name='us-west-2')
llama_client = LlamaCloud(api_key=LLAMACLOUD_API_KEY)

# Define Pydantic schemas for extraction
class OrderItem(BaseModel):
    product_code: str = Field(description="Product code")
    description: str = Field(description="Product description")
    quantity: int = Field(description="Quantity ordered")
    unit_price: float = Field(description="Unit price")
    total: float = Field(description="Line item total")

class Order(BaseModel):
    order_id: str = Field(description="Order ID")
    order_date: str = Field(description="Order date")
    customer_name: str = Field(description="Customer name")
    customer_email: str = Field(description="Customer email")
    items: List[OrderItem] = Field(description="Order items")
    subtotal: float = Field(description="Subtotal")
    tax: float = Field(description="Tax amount")
    total: float = Field(description="Total amount")

class InvoiceItem(BaseModel):
    product_code: str = Field(description="Product code")
    description: Optional[str] = Field(default="", description="Item description")
    quantity: int = Field(description="Quantity")
    unit_price: float = Field(description="Unit price")
    total: float = Field(description="Line item total")

class Invoice(BaseModel):
    invoice_id: str = Field(description="Invoice ID")
    invoice_date: str = Field(description="Invoice date")
    supplier_name: str = Field(description="Supplier name")
    payment_terms: str = Field(description="Payment terms")
    items: List[InvoiceItem] = Field(description="Invoice items")
    subtotal: Optional[float] = Field(default=0, description="Subtotal")
    tax: Optional[float] = Field(default=0, description="Tax")
    total: float = Field(description="Total amount")

class CatalogProduct(BaseModel):
    product_code: str = Field(description="Product code")
    name: str = Field(description="Product name")
    description: str = Field(description="Product description")
    price: float = Field(description="Product price")
    specifications: Optional[str] = Field(default="", description="Product specifications")

class Catalog(BaseModel):
    catalog_period: str = Field(description="Catalog period (e.g., Q1 2024)")
    products: List[CatalogProduct] = Field(description="Products in catalog")

SCHEMAS = {
    'orders': Order,
    'invoices': Invoice,
    'catalogs': Catalog
}

def download_from_s3(bucket: str, key: str, local_path: str):
    """Download file from S3"""
    s3_client.download_file(bucket, key, local_path)
    return local_path

def upload_to_s3(local_path: str, bucket: str, key: str):
    """Upload file to S3"""
    s3_client.upload_file(local_path, bucket, key)
    return f"s3://{bucket}/{key}"

def extract_document(pdf_path: str, schema: BaseModel, doc_type: str):
    """Extract structured data from PDF using LlamaCloud"""
    print(f"  Extracting {os.path.basename(pdf_path)}...")

    try:
        # Upload file to LlamaCloud
        with open(pdf_path, 'rb') as f:
            uploaded = llama_client.files.create(file=f, purpose='extract')

        print(f"    Uploaded file ID: {uploaded.id}")

        # Run extraction with schema
        result = llama_client.extraction.extract(
            file_id=uploaded.id,
            data_schema=schema.model_json_schema(),
            config={"extraction_mode": "BALANCED"}
        )

        # Get the extracted data
        if hasattr(result, 'data'):
            data = result.data
        elif isinstance(result, dict):
            data = result.get('data', result)
        else:
            data = result

        return data

    except Exception as e:
        print(f"    Error: {str(e)}")
        return None

def process_documents(doc_type: str, prefix: str):
    """Process all documents of a given type"""
    print(f"\n{'='*60}")
    print(f"Processing {doc_type.upper()} documents")
    print(f"{'='*60}")

    schema = SCHEMAS[doc_type]
    extracted_data = []

    # List documents in S3
    response = s3_client.list_objects_v2(
        Bucket=S3_BUCKET,
        Prefix=f"{S3_PREFIX}{prefix}/"
    )

    documents = [obj['Key'] for obj in response.get('Contents', []) if obj['Key'].endswith('.pdf')]
    print(f"Found {len(documents)} PDF documents")

    for doc_key in documents:
        local_path = f"/tmp/{doc_key.split('/')[-1]}"

        try:
            # Download from S3
            download_from_s3(S3_BUCKET, doc_key, local_path)

            # Extract data
            data = extract_document(local_path, schema, doc_type)

            if data:
                extracted_data.append(data)
                print(f"  ✓ Extracted: {doc_key.split('/')[-1]}")
            else:
                print(f"  ✗ Failed: {doc_key.split('/')[-1]}")

        except Exception as e:
            print(f"  ✗ Error: {doc_key}: {str(e)}")

    return extracted_data

def prepare_kb_data(extracted_data: list, doc_type: str):
    """Prepare extracted data for Knowledge Base ingestion"""
    print(f"\nPreparing {doc_type} data for Knowledge Base...")

    # For KB ingestion, we need to flatten the data
    # Each document should be a separate JSON file for better retrieval
    uploaded_files = []

    for i, doc in enumerate(extracted_data):
        # Create individual document file
        local_file = f"/tmp/{doc_type}_{i}.json"
        with open(local_file, 'w') as f:
            json.dump(doc, f, indent=2, default=str)

        # Determine unique identifier
        if doc_type == 'orders':
            doc_id = doc.get('order_id', f'order_{i}')
        elif doc_type == 'invoices':
            doc_id = doc.get('invoice_id', f'invoice_{i}')
        else:
            doc_id = doc.get('catalog_period', f'catalog_{i}').replace(' ', '_')

        s3_key = f"knowledge-base-data/{doc_type}/{doc_id}.json"
        upload_to_s3(local_file, S3_BUCKET, s3_key)
        uploaded_files.append(s3_key)
        print(f"  ✓ Uploaded: {s3_key}")

    return uploaded_files

def main():
    print("="*60)
    print("LLAMACLOUD DOCUMENT EXTRACTION")
    print("="*60)

    # Process each document type
    orders_data = process_documents('orders', 'orders')
    invoices_data = process_documents('invoices', 'invoices')
    catalogs_data = process_documents('catalogs', 'catalogs')

    # Prepare for KB ingestion
    print("\n" + "="*60)
    print("UPLOADING TO S3 FOR KNOWLEDGE BASE")
    print("="*60)

    if orders_data:
        prepare_kb_data(orders_data, 'orders')
    if invoices_data:
        prepare_kb_data(invoices_data, 'invoices')
    if catalogs_data:
        prepare_kb_data(catalogs_data, 'catalogs')

    print("\n" + "="*60)
    print("EXTRACTION COMPLETE")
    print("="*60)
    print(f"  Orders: {len(orders_data)} documents")
    print(f"  Invoices: {len(invoices_data)} documents")
    print(f"  Catalogs: {len(catalogs_data)} documents")
    print("\nNext: Sync Knowledge Bases to ingest the extracted data")

if __name__ == "__main__":
    main()
