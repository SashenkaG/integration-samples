DataSource["AWS S3"]
Chunking["Document Chunking"]
Embedding["Embedding Generation"]
Ingestion["Data Ingestion"]
VectorDB["PostgreSQL"]

DataSource --> Chunking
Chunking --> Embedding
Embedding --> Ingestion
Ingestion --> VectorDB