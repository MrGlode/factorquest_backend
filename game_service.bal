import ballerinax/mongodb;
import ballerina/log;

public function createResource(Resource res) returns Resource|error {
    mongodb:Collection resources = check getCollection(RESOURCES);

    json|error insertResult = check resources->insertOne(res);

    if insertResult is error {
        log:printError("Failed to create resource", 'error = insertResult);
        return error("Error creating resource");
    }
    log:printInfo("Resource created successfully: " + res.id);

    Resource createdResource = check findResourceById(res.id);
    return createdResource;
}

public function findResourceById(string resourceId) returns Resource|error {
    mongodb:Collection resources = check getCollection(RESOURCES);

    map<json> filter = {
        id: resourceId
    };

    Resource|mongodb:DatabaseError|mongodb:ApplicationError? result = check resources->findOne(filter);
    
    if result is mongodb:ApplicationError|mongodb:DatabaseError {
        log:printError("Failed to find resource by ID", 'error = result);
        return error("Error finding resource by ID");
    }
    
    if result is () {
        log:printInfo("Resource not found with ID: " + resourceId);
        return error("Resource not found");
    }

    return result;
}

public function listAllResources() returns Resource[]|error {
    mongodb:Collection resources = check getCollection(RESOURCES);

    map<json> filter = {};

    stream<Resource, error?>|mongodb:DatabaseError|mongodb:ApplicationError result = check resources->find(filter);

    if result is mongodb:ApplicationError|mongodb:DatabaseError {
        log:printError("Failed to list all resources", 'error = result);
        return error("Error listing all resources");
    }

    Resource[] resourceList = [];

    error? e = result.forEach(function(Resource res) {
        resourceList.push(res);
    });

    if e is error {
        log:printError("Error iterating over resources", 'error = e);
        return error("Error iterating over resources");
    }

    return resourceList;
}

public function deleteResource(string resourceId) returns error? {
    mongodb:Collection resources = check getCollection(RESOURCES);
    
    map<json> filter = {
        id: resourceId
    };

    mongodb:DeleteResult|mongodb:DatabaseError|mongodb:ApplicationError result = check resources->deleteOne(filter);

    if result is mongodb:ApplicationError|mongodb:DatabaseError {
        log:printError("Failed to delete resource", 'error = result);
        return error("Error deleting resource");
    }

    if result.deletedCount == 0 {
        log:printInfo("No resource found to delete with ID: " + resourceId);
        return error("Resource not found for deletion");
    }

    log:printInfo("Resource deleted successfully with ID: " + resourceId);
}

public function createRecipe(Recipe recipe) returns Recipe|error {
    mongodb:Collection recipes = check getCollection(RECIPES);

    check recipes->insertOne(recipe);

    Recipe createdRecipe = check findRecipeById(recipe.id);
    log:printInfo("Recipe created successfully: " + recipe.id);
    return createdRecipe;
}

public function findRecipeById(string recipeId) returns Recipe|error {
    mongodb:Collection recipes = check getCollection(RECIPES);

    map<json> filter = {
        id: recipeId
    };

    Recipe|mongodb:DatabaseError|mongodb:ApplicationError? result = check recipes->findOne(filter);

    if result is mongodb:ApplicationError|mongodb:DatabaseError {
        log:printError("Failed to find recipe by ID", 'error = result);
        return error("Error finding recipe by ID");
    }

    if result is () {
        log:printInfo("Recipe not found with ID: " + recipeId);
        return error("Recipe not found");
    }

    return result;
}

public function listAllRecipes() returns Recipe[]|error {
    mongodb:Collection recipes = check getCollection(RECIPES);

    map<json> filter = {};

    stream<Recipe, error?>|mongodb:DatabaseError|mongodb:ApplicationError result = check recipes->find(filter);

    if result is mongodb:ApplicationError|mongodb:DatabaseError {
        log:printError("Failed to list all recipes", 'error = result);
        return error("Error listing all recipes");
    }

    Recipe[] recipeList = [];

    error? e = result.forEach(function(Recipe rec) {
        recipeList.push(rec);
    });

    if e is error {
        log:printError("Error iterating over recipes", 'error = e);
        return error("Error iterating over recipes");
    }

    return recipeList;
}

public function deleteRecipe(string recipeId) returns error? {
    mongodb:Collection recipes = check getCollection(RECIPES);
    
    map<json> filter = {
        id: recipeId
    };

    mongodb:DeleteResult|mongodb:DatabaseError|mongodb:ApplicationError result = check recipes->deleteOne(filter);

    if result is mongodb:ApplicationError|mongodb:DatabaseError {
        log:printError("Failed to delete recipe", 'error = result);
        return error("Error deleting recipe");
    }

    if result.deletedCount == 0 {
        log:printInfo("No recipe found to delete with ID: " + recipeId);
        return error("Recipe not found for deletion");
    }

    log:printInfo("Recipe deleted successfully with ID: " + recipeId);
}

public function listRecipesByMachinetype(MachineType machineType) returns Recipe[]|error {
    mongodb:Collection recipes = check getCollection(RECIPES);

    map<json> filter = {
        machineType: machineType
    };

    stream<Recipe, error?>|mongodb:DatabaseError|mongodb:ApplicationError result = check recipes->find(filter);

    if result is mongodb:ApplicationError|mongodb:DatabaseError {
        log:printError("Failed to list recipes by machinetype", 'error = result);
        return error("Error listing recipes by machinetype");
    }

    Recipe[] recipeList = [];

    error? e = result.forEach(function(Recipe rec) {
        recipeList.push(rec);
    });

    if e is error {
        log:printError("Error iterating over recipes", 'error = e);
        return error("Error iterating over recipes");
    }

    return recipeList;
}

public function initializeDefaultResources() returns error? {
    Resource[] defaultResources = [
        { id: "iron_ore", name: "Minerai de fer", icon: "🔵" },
        { id: "copper_ore", name: "Minerai de cuivre", icon: "🟤" },
        { id: "coal", name: "Charbon", icon: "⚫" },
        { id: "iron_plate", name: "Plaque de fer", icon: "🔹" },
        { id: "copper_plate", name: "Plaque de cuivre", icon: "🟠" },
        { id: "iron_wire", name: "Fil de fer", icon: "🔗" },
        { id: "gear", name: "Engrenage", icon: "⚙️" }
    ];

    foreach Resource res in defaultResources {
        Resource|error existingRes = findResourceById(res.id);
        if existingRes is error {
           _= check createResource(res);
        } else {
            log:printInfo("Resource already exists: " + res.id);
        }        
    }

    log:printInfo("Default resources initialization complete.");
}

public function initializeDefaultRecipes() returns error? {
    Recipe[] defaultRecipes = [
        // Mines
        {
            id: "mine_iron",
            name: "Extraction fer",
            inputs: [],
            outputs: [{ resourceId: "iron_ore", quantity: 1 }],
            duration: 1.0d,
            machineType: "mine"
        },
        {
            id: "mine_copper",
            name: "Extraction cuivre",
            inputs: [],
            outputs: [{ resourceId: "copper_ore", quantity: 1 }],
            duration: 1.5d,
            machineType: "mine"
        },
        {
            id: "mine_coal",
            name: "Extraction charbon",
            inputs: [],
            outputs: [{ resourceId: "coal", quantity: 1 }],
            duration: 0.8d,
            machineType: "mine"
        },
        // Fours
        {
            id: "smelt_iron",
            name: "Fonte fer",
            inputs: [
                { resourceId: "iron_ore", quantity: 3 },
                { resourceId: "coal", quantity: 1 }
            ],
            outputs: [{ resourceId: "iron_plate", quantity: 1 }],
            duration: 3.0d,
            machineType: "furnace"
        },
        {
            id: "smelt_copper",
            name: "Fonte cuivre",
            inputs: [
                { resourceId: "copper_ore", quantity: 2 },
                { resourceId: "coal", quantity: 1 }
            ],
            outputs: [{ resourceId: "copper_plate", quantity: 1 }],
            duration: 2.5d,
            machineType: "furnace"
        },
        // Assembleurs
        {
            id: "craft_wire",
            name: "Fabrication fil",
            inputs: [{ resourceId: "iron_plate", quantity: 2 }],
            outputs: [{ resourceId: "iron_wire", quantity: 1 }],
            duration: 5.0d,
            machineType: "assembler"
        },
        {
            id: "craft_gear",
            name: "Fabrication engrenage",
            inputs: [
                { resourceId: "iron_plate", quantity: 2 },
                { resourceId: "iron_wire", quantity: 1 }
            ],
            outputs: [{ resourceId: "gear", quantity: 1 }],
            duration: 8.0d,
            machineType: "assembler"
        }
    ];

    foreach Recipe rec in defaultRecipes {
        Recipe|error existingRec = findRecipeById(rec.id);
        if existingRec is error {
           _= check createRecipe(rec);
        } else {
            log:printInfo("Recipe already exists: " + rec.id);
        }        
    }
}

