import ballerinax/openai.chat;
import ballerinax/openai.embeddings;
import ballerinax/pinecone.vector;
import ballerina/io;

embeddings:Client? embeddingsClient = ();
vector:Client? pineconeVectorClient = ();
chat:Client? openAIChat = ();

function init() {
    io:println("=== HR AI Chat Agent Initialization Started ===");
    
    // Print received tokens/keys for debugging
    io:println("Received OPENAI_TOKEN: " + (OPENAI_TOKEN != "" ? OPENAI_TOKEN : "<EMPTY>"));
    io:println("Received PINECONE_API_KEY: " + (PINECONE_API_KEY != "" ? PINECONE_API_KEY : "<EMPTY>"));
    io:println("Received PINECONE_URL: " + (PINECONE_URL != "" ? PINECONE_URL : "<EMPTY>"));
    
    // Initialize embeddings client
    io:println("Creating OpenAI embeddings client...");
    embeddings:Client|error embeddingsClientResult = new ({
        auth: {
            token: OPENAI_TOKEN
        }
    });
    
    if embeddingsClientResult is embeddings:Client {
        embeddingsClient = embeddingsClientResult;
        io:println("Embeddings client created successfully");
    } else {
        io:println("ERROR creating embeddings client: " + embeddingsClientResult.message());
        io:println("Error detail: " + embeddingsClientResult.toString());
    }
    
    // Initialize Pinecone vector client
    io:println("Creating Pinecone vector client...");
    vector:Client|error pineconeVectorClientResult = new ({
        apiKey: PINECONE_API_KEY
    }, serviceUrl = PINECONE_URL);

    if pineconeVectorClientResult is vector:Client {
        pineconeVectorClient = pineconeVectorClientResult;
        io:println("Pinecone vector client created successfully");
    } else {
        io:println("ERROR creating Pinecone vector client: " + pineconeVectorClientResult.message());
        io:println("Error detail: " + pineconeVectorClientResult.toString());
    }
    
    // Initialize OpenAI chat client
    io:println("Creating OpenAI chat client...");
    chat:Client|error openAIChatResult = new ({
        auth: {
            token: OPENAI_TOKEN
        }
    });
    
    if openAIChatResult is chat:Client {
        openAIChat = openAIChatResult;
        io:println("[OpenAI chat client created successfully");
    } else {
        io:println("ERROR creating OpenAI chat client: " + openAIChatResult.message());
        io:println("Error detail: " + openAIChatResult.toString());
    }
    
    io:println("=== HR AI Chat Agent Initialization Complete ===");
}

final string embedding = "text-embed";

vector:QueryRequest queryRequest = {
    topK: 4,
    includeMetadata: true
};

public type Metadata record {
    string text;
};

public type ChatResponseChoice record {|
    chat:ChatCompletionResponseMessage message?;
    int index?;
    string finish_reason?;
    anydata...;
|};

function llmChat(string query) returns string|error {
    io:println("[llmChat] Processing query: " + query);
    float[] embeddingsFloat = check getEmbeddings(query);
    queryRequest.vector = embeddingsFloat;
    vector:QueryMatch[] matches = check retrieveData(queryRequest);
    string context = check augment(matches);
    string chatResponse = check generateText(query, context);
    io:println("Chat response generated successfully");
    return chatResponse;
}

function getEmbeddings(string query) returns float[]|error {
    embeddings:CreateEmbeddingRequest req = {
        model: "text-embedding-ada-002",
        input: query
    };
    
    embeddings:Client? clientRef = embeddingsClient;
    if clientRef is () {
        io:println("ERROR: Embeddings client not initialized");
        return error("Embeddings client is not initialized. Check initialization logs.");
    }
    
    embeddings:CreateEmbeddingResponse embeddingsResult = check clientRef->/embeddings.post(req);
    io:println("Embeddings received, dimension: " + embeddingsResult.data[0].embedding.length().toString());

    float[] embeddings = embeddingsResult.data[0].embedding;
    return embeddings;
}

function retrieveData(vector:QueryRequest queryRequest) returns vector:QueryMatch[]|error {
    vector:Client? clientRef = pineconeVectorClient;
    if clientRef is () {
        io:println("ERROR: Pinecone client not initialized");
        return error("Pinecone vector client is not initialized. Check initialization logs.");
    }
    
    vector:QueryResponse response = check clientRef->/query.post(queryRequest);
    vector:QueryMatch[]? matches = response.matches;
    if (matches == null) {
        io:println("WARNING: No matches found");
        return error("No matches found");
    }
    io:println("Retrieved " + matches.length().toString() + " matches from Pinecone");
    return matches;
}

isolated function augment(vector:QueryMatch[] matches) returns string|error {
    string context = "";
    foreach vector:QueryMatch data in matches {
        Metadata metadata = check data.metadata.cloneWithType();
        context = context.concat(metadata.text);
    }
    return context;
}

function generateText(string query, string context) returns string|error {
    string systemPrompt = string `You are an HR Policy Assistant that provides employees with accurate answers
        based on company HR policies.Your responses must be clear and strictly based on the provided context.
        ${context}`;

    chat:CreateChatCompletionRequest request = {
        model: "gpt-4o-mini",
        messages: [{
            "role": "system",
            "content": systemPrompt
        },
        {
            "role": "user",
            "content": query
        }
        ]
    };

    chat:Client? clientRef = openAIChat;
    if clientRef is () {
        io:println("ERROR: OpenAI chat client not initialized");
        return error("OpenAI chat client is not initialized. Check initialization logs.");
    }
    
    chat:CreateChatCompletionResponse chatResult = 
        check clientRef->/chat/completions.post(request);
    ChatResponseChoice[] choices = check chatResult.choices.ensureType();
    string? chatResponse = choices[0].message?.content;

    if (chatResponse == null) {
        io:println("ERROR: No content in chat response");
        return error("No chat response found");
    }
    io:println("Generated response with " + chatResponse.length().toString() + " characters");
    return chatResponse;
}
