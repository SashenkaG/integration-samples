DataSource["Google Drive"]
Chunking["Document Chunking"]
Embedding["Embedding Generation"]
Ingestion["Data Ingestion"]
VectorDB["Weaviate"]

DataSource --> Chunking
Chunking --> Embedding
Embedding --> Ingestion
Ingestion --> VectorDB