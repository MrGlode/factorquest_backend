import ballerinax/mongodb;
import ballerina/log;

mongodb:Client mongoClient = check initMongoClient();

public enum CollectionNames {
    USERS = "users",
    PLAYERS = "players",
    GAME_STATES = "game_states",
    INVENTORIES = "inventories",
    MACHINES = "machines",
    ACHIEVEMENTS = "achievements",
    LEADERBOARD = "leaderboard",
    TRANSACTIONS = "transactions",
    RESET_TOKENS = "reset_tokens",
    RESOURCES = "resources",
    RECIPES = "recipes",
    MARKET_BASE_PRICES = "market_base_prices",
    MARKET_CLIENTS = "market_clients",
    MARKET_CLIENTS_MULTIPLIERS = "market_clients_multipliers",
    MARKET_PRICES = "market_prices",
    SPECIAL_ORDERS = "special_orders",
    LABORATORY_TYPES = "laboratory_types",
    LABORATORIES = "laboratories",
    RESEARCHES = "researches",
    RESEARCH_PROGRESS = "research_progress",
    COMPLETED_RESEARCHES = "completed_researches"
};

function initMongoClient() returns mongodb:Client|error {
    string connectionUrl = string `mongodb://${db_host}:${db_port}`;
    
    mongodb:Client clientDb = check new ({
        connection: connectionUrl
    });
    
    log:printInfo("MongoDB client initialized successfully.");
    return clientDb;
}

public function getDatabase() returns mongodb:Database|error {
    return mongoClient->getDatabase(db_database);
}

public function getCollection(string collectionName) returns mongodb:Collection|error {
    mongodb:Database db = check getDatabase();
    return db->getCollection(collectionName);
}