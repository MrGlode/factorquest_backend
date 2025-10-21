import ballerina/http;
import ballerina/log;

service /game on new http:Listener(server_port + 3) {
    resource function get 'resources() returns Resource[]|http:InternalServerError {
        Resource[]|error resources = listAllResources();
        if (resources is error) {
            log:printError("Erreur lors de la récupération des ressources", 'error = resources);
             return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération des ressources."
                }
            };
        }
        return resources;
    }

    resource function get 'resource/[string resourceId]() returns Resource|http:NotFound|http:InternalServerError {
        Resource|error res = findResourceById(resourceId);
        if (res is error) {
            log:printError("Erreur lors de la récupération de la ressource", 'error = res);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération de la ressource."
                }
            };
        }     
        return res;
    }

    resource function get recipes(string? machineType) returns Recipe[]|http:InternalServerError {
        Recipe[]|error recipes;

        if machineType is string {
            MachineType mt = <MachineType>machineType;
            recipes = listRecipesByMachineType(mt);
        } else {
            recipes = listAllRecipes();
        }

        if (recipes is error) {
            log:printError("Erreur lors de la récupération des recettes", 'error = recipes);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération des recettes."
                }
            };
        }
        return recipes;
    }

    resource function get recipe/[string recipeId]() returns Recipe|http:NotFound|http:InternalServerError {
        Recipe|error recipe = findRecipeById(recipeId);
        if (recipe is error) {
            log:printError("Erreur lors de la récupération de la recette", 'error = recipe);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération de la recette."
                }
            };
        }
        return recipe;
    }

    resource function get state(@http:Header string appauth) returns GameStateResponse|http:Unauthorized|http:NotFound|http:InternalServerError {
        //string token = appauth.substring(7);
        JwtPayload|error payload = validateToken(appauth);
        if (payload is error) {
            log:printError("Token invalide", 'error = payload);
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide."
                }
            };
        }

        GameStateResponse|error state = getCompleteGameState(payload.sub);
        if (state is error) {
            log:printError("Erreur lors de la récupération de l'état du jeu", 'error = state);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération de l'état du jeu."
                }
            };
        }
        return state;
    }

    resource function put state(@http:Header string appauth, UpdateGameStateRequest req) returns http:Ok|http:Unauthorized|http:InternalServerError {
        JwtPayload|error payload = validateToken(appauth);
        if (payload is error) {
            log:printError("Token invalide", 'error = payload);
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide."
                }
            };
        }

        error? updateResult = updateGameState(payload.sub, req);
        if (updateResult is error) {
            log:printError("Erreur lors de la mise à jour de l'état du jeu", 'error = updateResult);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la mise à jour de l'état du jeu."
                }
            };
        }

        return <http:Ok>{
            body: {
                message: "État du jeu mis à jour avec succès."
            }
        };
    }

    resource function get inventory(@http:Header string appauth) returns Inventory|http:Unauthorized|http:NotFound|http:InternalServerError {
        JwtPayload|error payload = validateToken(appauth);
        if (payload is error) {
            log:printError("Token invalide", 'error = payload);
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide."
                }
            };
        }

        Inventory|error inventory = findInventoryByUserId(payload.sub);
        if (inventory is error) {
            log:printError("Erreur lors de la récupération de l'inventaire", 'error = inventory);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération de l'inventaire."
                }
            };
        }
        return inventory;
    }

    resource function put inventory(@http:Header string appauth, InventoryItem[] items) returns http:Ok|http:Unauthorized|http:InternalServerError {
        JwtPayload|error payload = validateToken(appauth);
        
        if payload is error {
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide ou expiré"
                }
            };
        }
        
        error? updateResult = updateInventory(payload.sub, items);
        
        if updateResult is error {
            log:printError("Error updating inventory", updateResult);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la mise à jour de l'inventaire"
                }
            };
        }
        
        return <http:Ok>{
            body: {
                message: "Inventaire mis à jour"
            }
        };
    }

    resource function get machines(@http:Header string appauth) returns Machine[]|http:Unauthorized|http:NotFound|http:InternalServerError {
        JwtPayload|error payload = validateToken(appauth);
        if (payload is error) {
            log:printError("Token invalide", 'error = payload);
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide."
                }
            };
        }

        Machine[]|error machines = findMachinesByUserId(payload.sub);
        if (machines is error) {
            log:printError("Erreur lors de la récupération des machines", 'error = machines);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération des machines."
                }
            };
        }
        return machines;
    }

    resource function post machines(@http:Header string appauth, CreateMachineRequest req) returns Machine|http:Unauthorized|http:InternalServerError|http:UnprocessableEntity {
        JwtPayload|error payload = validateToken(appauth);
        if (payload is error) {
            log:printError("Token invalide", 'error = payload);
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide."
                }
            };
        }

        if req.'type != "mine" && req.'type != "furnace" && req.'type != "assembler" {
            return <http:InternalServerError>{
                body: {
                    message: "Type de machine invalide. Doit être 'mine', 'furnace' ou 'assembler'."
                }
            };
        }

        Machine|error createdMachine = createMachine(req, payload.sub);

        if (createdMachine is error) {
            if (createdMachine.message().includes("Fonds insuffisants")) {
                return <http:UnprocessableEntity>{
                    body: {
                        message: createdMachine.message()
                    }
                };
            }
            log:printError("Erreur lors de la création de la machine", 'error = createdMachine);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la création de la machine."
                }
            };
        }
        return createdMachine;
    }

    resource function get machines/[string machineId](@http:Header string appauth) returns Machine|http:Unauthorized|http:NotFound|http:InternalServerError {
        JwtPayload|error payload = validateToken(appauth);

        if payload is error {
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide ou expiré"
                }
            };
        }
        
        // Récupérer la machine (vérification userId incluse)
        Machine|error machine = findMachineById(machineId, payload.sub);
        
        if machine is error {
            if machine.message().includes("not found") {
                return <http:NotFound>{
                    body: {
                        message: "Machine non trouvée"
                    }
                };
            }
            
            log:printError("Error fetching machine", machine);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération de la machine"
                }
            };
        }
        
        return machine;
    }

    resource function put machines/[string machineId](@http:Header string appauth, UpdateMachineRequest req) returns http:Ok|http:Unauthorized|http:NotFound|http:InternalServerError {
        JwtPayload|error payload = validateToken(appauth);
        
        if payload is error {
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide ou expiré"
                }
            };
        }
        
        // Mettre à jour la machine
        error? updateResult = updateMachine(machineId, payload.sub, req);
        
        if updateResult is error {
            log:printError("Error updating machine", updateResult);
            
            if updateResult.message().includes("not found") {
                return <http:NotFound>{
                    body: {
                        message: "Machine non trouvée"
                    }
                };
            }
            
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la mise à jour de la machine"
                }
            };
        }
        
        return <http:Ok>{
            body: {
                message: "Machine mise à jour"
            }
        };
    }

    resource function delete machines/[string machineId](@http:Header string appauth) returns http:Ok|http:Unauthorized|http:NotFound|http:InternalServerError {
        JwtPayload|error payload = validateToken(appauth);

        if payload is error {
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide ou expiré"
                }
            };
        }
        
        // Supprimer la machine
        error? deleteResult = deleteMachine(machineId, payload.sub);
        
        if deleteResult is error {
            log:printError("Error deleting machine", deleteResult);
            
            if deleteResult.message().includes("not found") {
                return <http:NotFound>{
                    body: {
                        message: "Machine non trouvée"
                    }
                };
            }
            
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la suppression de la machine"
                }
            };
        }
        
        return <http:Ok>{
            body: {
                message: "Machine supprimée"
            }
        };
    }
}