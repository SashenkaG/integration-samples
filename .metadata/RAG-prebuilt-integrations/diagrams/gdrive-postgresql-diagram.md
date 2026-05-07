DataSource["Google Drive"]
Chunking["Document Chunking"]
Embedding["Embedding Generation"]
Ingestion["Data Ingestion"]
VectorDB["PostgreSQL"]

DataSource --> Chunking
Chunking --> Embedding
Embedding --> Ingestion
Ingestion --> VectorDB