import ballerina/log;
import ballerinax/mongodb;
import ballerina/time;
import ballerina/uuid;

public function createGameState(string userId, decimal initialMoney = 1000.0) returns GameState|error {
    mongodb:Collection gameStates = check getCollection(GAME_STATES);

    time:Utc now = time:utcNow();

    GameState gameState = {
        id: uuid:createType1AsString(),
        userId: userId,
        money: initialMoney,
        lastSavedTime: now,
        totalPlayTime: 0
    };

    check gameStates->insertOne(gameState);
    
    GameState createdState = check findGameStateByUserId(userId);
    log:printInfo("Created initial game state for user: " + userId);
    return createdState;
}

public function findGameStateByUserId(string userId) returns GameState|error {
    mongodb:Collection gameState = check getCollection(GAME_STATES);
    
    map<json> filter = {
        "userId": userId
    };

    GameState|mongodb:DatabaseError|mongodb:ApplicationError? result = check gameState->findOne(filter);
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error retrieving game state for user: " + userId, 'error = result);
        return error("Failed to retrieve game state.");
    }

    if result is () {
        log:printInfo("No game state found for user: " + userId);
        return error("Game state not found.");
    }

    return result;
}

public function updateGameState(string userId, UpdateGameStateRequest updateRequest) returns error? {
    mongodb:Collection gameStates = check getCollection(GAME_STATES);

    map<json> filter = {
        "userId": userId
    };

    map<json> updateFields = {
        "lastSavedTime": time:utcNow()
    };

    if updateRequest.money is decimal {
        updateFields["money"] = updateRequest.money;
    }

    if updateRequest.totalPlayTime is int {
        updateFields["totalPlayTime"] = updateRequest.totalPlayTime;
    }

    mongodb:Update update = {
        set: { "money": updateFields["money"],
                "lastSavedTime": time:utcNow(),
                "totalPlayTime": updateFields["totalPlayTime"]
        }
    };

    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError result = check gameStates->updateOne(filter, update);
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error updating game state for user: " + userId, 'error = result);
        return error("Failed to update game state.");
    }
    if result.matchedCount == 0 {
        log:printInfo("No game state found to update for user: " + userId);
        return error("Game state not found.");
    }
    log:printInfo("Updated game state for user: " + userId);
}

public function createInventory(string userId) returns Inventory|error {
    mongodb:Collection inventories = check getCollection(INVENTORIES);

    time:Utc now = time:utcNow();

    Inventory inventory = {
        id: uuid:createType1AsString(),
        userId: userId,
        items: [],
        lastUpdated: now
    };

    check inventories->insertOne(inventory);
    
    Inventory createdInventory = check findInventoryByUserId(userId);
    log:printInfo("Created initial inventory for user: " + userId);
    return createdInventory;
}

public function findInventoryByUserId(string userId) returns Inventory|error {
    mongodb:Collection inventories = check getCollection(INVENTORIES);
    
    map<json> filter = {
        "userId": userId
    };

    Inventory|mongodb:DatabaseError|mongodb:ApplicationError? result = check inventories->findOne(filter);
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error retrieving inventory for user: " + userId, 'error = result);
        return error("Failed to retrieve inventory.");
    }

    if result is () {
        log:printInfo("No inventory found for user: " + userId);
        return error("Inventory not found.");
    }

    return result;
}

public function updateInventory(string userId, InventoryItem[] items) returns error? {
    mongodb:Collection inventories = check getCollection(INVENTORIES);

    map<json> filter = {
        "userId": userId
    };

    mongodb:Update update = {
        set: {
            "items": items,
            "lastUpdated": time:utcNow()
        }
    };

    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError result = check inventories->updateOne(filter, update);
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error updating inventory for user: " + userId, 'error = result);
        return error("Failed to update inventory.");
    }
    if result.matchedCount == 0 {
        log:printInfo("No inventory found to update for user: " + userId);
        return error("Inventory not found.");
    }
    log:printInfo("Updated inventory for user: " + userId);
}

public function createMachine(CreateMachineRequest createRequest, string userId) returns Machine|error {
    mongodb:Collection machines = check getCollection(MACHINES);

    time:Utc now = time:utcNow();

    Machine dbMachine = check findMachineByType(createRequest.'type);
    decimal costMachine = 0.0d;
    if dbMachine is Machine {
        costMachine = dbMachine.cost;
    } 

    GameState state = check findGameStateByUserId(userId);
    if state.money < costMachine {
        return error("Fonds insuffisants : " + getMachineTypeName(createRequest.'type));
    }

    error? debitError = debitMoney(userId, costMachine);
    if debitError is error {
        _ = check machines->deleteOne({ "id": dbMachine.id });
        log:printError("Échec du débit d'argent pour l'utilisateur : " + userId + " lors de la création de la machine de type : " + getMachineTypeName(createRequest.'type), 'error = debitError);
        return error("Échec de la création de la machine en raison d'une erreur de paiement.");
    }

    Machine machine = {
        id: uuid:createType1AsString(),
        userId: userId,
        'type: createRequest.'type,
        name: dbMachine.name,
        cost: costMachine,
        selectedRecipeId: (),
        lastProductionTime: now,
        pauseProgress: 0.0d,
        isActive: false,
        createdAt: now
    };
    
    check machines->insertOne(machine);
    Machine createdMachine = check findMachineById(machine.id, userId);
    log:printInfo("Created machine " + machine.id + " for user: " + userId);
    return createdMachine;
}

public function debitMoney(string userId, decimal amount) returns error? {
    mongodb:Collection gameStates = check getCollection(GAME_STATES);
    map<json> filter = {
        "userId": userId
    };
    
    mongodb:Update update = {
        inc: { "money": -amount },
        set: { "lastSavedTime": time:utcNow() }
    };

    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError result = check gameStates->updateOne(filter, update);
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error debiting money for user: " + userId, 'error = result);
        return error("Failed to debit money.");
    }

    if result.matchedCount == 0 {
        log:printInfo("No game state found to debit money for user: " + userId);
        return error("Game state not found.");
    }

    log:printInfo("Debited " + amount.toString() + " from user: " + userId);
}

public function findMachinesByUserId(string userId) returns Machine[]|error {
    mongodb:Collection machines = check getCollection(MACHINES);
    
    map<json> filter = {
        "userId": userId
    };

    mongodb:FindOptions options = {
        sort: { "createdAt": 1 }
    };

    stream<Machine, error?>|mongodb:DatabaseError|mongodb:ApplicationError resultStream = check machines->find(filter, options);

    if resultStream is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error retrieving machines for user: " + userId, 'error = resultStream);
        return error("Failed to retrieve machines.");
    }

    Machine[] result = [];
    error? e = resultStream.forEach(function (Machine machine) {
        result.push(machine);
    });

    if e is error {
        log:printError("Error processing machines for user: " + userId, 'error = e);
        return error("Failed to process machines.");
    }


    return result;
}

public function findMachineById(string machineId, string userId) returns Machine|error {
    mongodb:Collection machines = check getCollection(MACHINES);
    
    map<json> filter = {
        "id": machineId,
        "userId": userId
    };

    Machine|mongodb:DatabaseError|mongodb:ApplicationError? result = check machines->findOne(filter);

    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error retrieving machine " + machineId + " for user: " + userId, 'error = result);
        return error("Failed to retrieve machine.");
    }

    if result is () {
        log:printInfo("No machine found with ID " + machineId + " for user: " + userId);
        return error("Machine not found.");
    }

    return result;
}

public function updateMachine(string machineId, string userId, UpdateMachineRequest updateRequest) returns error? {
    mongodb:Collection machines = check getCollection(MACHINES);

    map<json> filter = {
        "id": machineId,
        "userId": userId
    };

    map<json> updateFields = {};

    if updateRequest.selectedRecipeId is string? {
        updateFields["selectedRecipeId"] = updateRequest.selectedRecipeId;
    }
    if updateRequest.isActive is boolean {
        updateFields["isActive"] = updateRequest.isActive;
    }
    if updateRequest.pauseProgress is decimal {
        updateFields["pauseProgress"] = updateRequest.pauseProgress;
    }
    if updateRequest.lastProductionTime is time:Utc {
        updateFields["lastProductionTime"] = updateRequest.lastProductionTime;
    }

    if updateFields.length() == 0 {
        return error("No fields to update.");
    }

    mongodb:Update update = {
        set: {
            "selectedRecipeId": updateFields["selectedRecipeId"],
            "isActive": updateFields["isActive"],
            "pauseProgress": updateFields["pauseProgress"],
            "lastProductionTime": updateFields["lastProductionTime"]
        }
    };

    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError result = check machines->updateOne(filter, update);

    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error updating machine " + machineId + " for user: " + userId, 'error = result);
        return error("Failed to update machine.");
    }
    if result.matchedCount == 0 {
        log:printInfo("No machine found to update with ID " + machineId + " for user: " + userId);
        return error("Machine not found.");
    }

    log:printInfo("Updated machine " + machineId + " for user: " + userId);
}

public function deleteMachine(string machineId, string userId) returns error? {
    mongodb:Collection machines = check getCollection(MACHINES);

    map<json> filter = {
        "id": machineId,
        "userId": userId
    };

    mongodb:DeleteResult|mongodb:DatabaseError|mongodb:ApplicationError result = check machines->deleteOne(filter);

    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error deleting machine " + machineId + " for user: " + userId, 'error = result);
        return error("Failed to delete machine.");
    }
    if result.deletedCount == 0 {
        log:printInfo("No machine found to delete with ID " + machineId + " for user: " + userId);
        return error("Machine not found.");
    }

    log:printInfo("Deleted machine " + machineId + " for user: " + userId);
}

function getMachineTypeName(MachineType machineType) returns string {
    match machineType {
        "mine" => {
            return "Mine";
        }
        "furnace" => {
            return "Four";
        }
        "assembler" => {
            return "Assembleur";
        }
    }
    return "Unknown";
}

public function getCompleteGameState(string userId) returns GameStateResponse|error {
    GameState gameState = check findGameStateByUserId(userId);
    Inventory inventory = check findInventoryByUserId(userId);
    Machine[] machines = check findMachinesByUserId(userId);
    
    return {
        state: gameState,
        inventory: inventory,
        machines: machines
    };
}
