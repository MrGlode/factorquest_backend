import ballerina/http;
import ballerina/log;

service /research on new http:Listener(server_port + 5) {
    resource function get laboratories(@http:Header string Authorization) returns LaboratoriesResponse|http:Unauthorized|http:InternalServerError {
        
        string token = Authorization.substring(7);
        JwtPayload|error payload = validateToken(token);
        
        if payload is error {
            log:printError("Token invalide", 'error = payload);
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide ou expiré."
                }
            };
        }
        
        Laboratory[]|error labs = getUserLaboratories(payload.sub);
        
        if labs is error {
            log:printError("Erreur lors de la récupération des laboratoires", 'error = labs);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération des laboratoires."
                }
            };
        }
        
        return {
            laboratories: labs
        };
    }

    resource function post laboratories(@http:Header string Authorization, PurchaseLaboratoryRequest req) returns PurchaseLaboratoryResponse|http:BadRequest|http:Unauthorized|http:InternalServerError {
        
        string token = Authorization.substring(7);
        JwtPayload|error payload = validateToken(token);
        
        if payload is error {
            log:printError("Token invalide", 'error = payload);
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide ou expiré."
                }
            };
        }
        
        // Valider le type de laboratoire
        if req.'type != "basic" && req.'type != "advanced" && req.'type != "institute" 
            && req.'type != "mining" && req.'type != "metallurgy" && req.'type != "mechanical" {
            return <http:BadRequest>{
                body: {
                    message: "Type de laboratoire invalide."
                }
            };
        }
        
        PurchaseLaboratoryResponse|error result = purchaseLaboratory(payload.sub, req.'type);
        
        if result is error {
            log:printError("Erreur lors de l'achat du laboratoire", 'error = result);
            
            string errorMsg = result.message();
            if errorMsg.includes("Insufficient funds") {
                return <http:BadRequest>{
                    body: {
                        message: "Fonds insuffisants pour acheter ce laboratoire."
                    }
                };
            }
            
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de l'achat du laboratoire."
                }
            };
        }
        
        return result;
    }

    resource function get available() returns ResearchesResponse|http:InternalServerError {
        
        Research[]|error researches = getAllResearches();
        
        if researches is error {
            log:printError("Erreur lors de la récupération des recherches", 'error = researches);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération des recherches."
                }
            };
        }
        
        return {
            researches: researches
        };
    }

    resource function get available/[string researchId]() returns Research|http:NotFound|http:InternalServerError {
        
        Research|error research = getResearchById(researchId);
        
        if research is error {
            log:printError("Erreur lors de la récupération de la recherche", 'error = research);
            
            if research.message().includes("not found") {
                return <http:NotFound>{
                    body: {
                        message: "Recherche non trouvée."
                    }
                };
            }
            
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération de la recherche."
                }
            };
        }
        
        return research;
    }

    resource function get active(@http:Header string Authorization) returns ActiveResearchesResponse|http:Unauthorized|http:InternalServerError {
        
        string token = Authorization.substring(7);
        JwtPayload|error payload = validateToken(token);
        
        if payload is error {
            log:printError("Token invalide", 'error = payload);
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide ou expiré."
                }
            };
        }
        
        ResearchProgress[]|error activeResearches = getActiveResearches(payload.sub);
        
        if activeResearches is error {
            log:printError("Erreur lors de la récupération des recherches actives", 'error = activeResearches);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération des recherches actives."
                }
            };
        }
        
        return {
            activeResearches: activeResearches
        };
    }

    resource function post 'start(@http:Header string Authorization, StartResearchRequest req) returns StartResearchResponse|http:BadRequest|http:Unauthorized|http:InternalServerError {
        
        string token = Authorization.substring(7);
        JwtPayload|error payload = validateToken(token);
        
        if payload is error {
            log:printError("Token invalide", 'error = payload);
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide ou expiré."
                }
            };
        }
        
        StartResearchResponse|error result = startResearch(payload.sub, req.researchId, req.laboratoryId);
        
        if result is error {
            log:printError("Erreur lors du démarrage de la recherche", 'error = result);
            
            string errorMsg = result.message();
            
            // Erreurs métier à retourner en 400 Bad Request
            if errorMsg.includes("not found") 
                || errorMsg.includes("already completed")
                || errorMsg.includes("already in progress")
                || errorMsg.includes("full")
                || errorMsg.includes("Prerequisite")
                || errorMsg.includes("Insufficient") {
                return <http:BadRequest>{
                    body: {
                        message: errorMsg
                    }
                };
            }
            
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors du démarrage de la recherche."
                }
            };
        }
        
        return result;
    }

    resource function post complete/[string researchId](@http:Header string Authorization) returns http:Ok|http:BadRequest|http:Unauthorized|http:InternalServerError {
        
        string token = Authorization.substring(7);
        JwtPayload|error payload = validateToken(token);
        
        if payload is error {
            log:printError("Token invalide", 'error = payload);
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide ou expiré."
                }
            };
        }
        
        error? result = completeResearch(payload.sub, researchId);
        
        if result is error {
            log:printError("Erreur lors de la complétion de la recherche", 'error = result);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la complétion de la recherche."
                }
            };
        }
        
        return <http:Ok>{
            body: {
                message: "Recherche complétée avec succès."
            }
        };
    }

    resource function get completed(@http:Header string Authorization) returns CompletedResearchesResponse|http:Unauthorized|http:InternalServerError {
        
        string token = Authorization.substring(7);
        JwtPayload|error payload = validateToken(token);
        
        if payload is error {
            log:printError("Token invalide", 'error = payload);
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide ou expiré."
                }
            };
        }
        
        CompletedResearch[]|error completed = getCompletedResearches(payload.sub);
        
        if completed is error {
            log:printError("Erreur lors de la récupération des recherches complétées", 'error = completed);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération des recherches complétées."
                }
            };
        }
        
        return {
            completedResearches: completed
        };
    }

    resource function get effects(@http:Header string Authorization) returns ActiveEffectsResponse|http:Unauthorized|http:InternalServerError {
        
        string token = Authorization.substring(7);
        JwtPayload|error payload = validateToken(token);
        
        if payload is error {
            log:printError("Token invalide", 'error = payload);
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide ou expiré."
                }
            };
        }
        
        ResearchEffect[]|error effects = getActiveEffects(payload.sub);
        
        if effects is error {
            log:printError("Erreur lors de la récupération des effets actifs", 'error = effects);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération des effets actifs."
                }
            };
        }
        
        map<decimal>|error bonuses = calculateBonuses(payload.sub);
        
        if bonuses is error {
            log:printError("Erreur lors du calcul des bonus", 'error = bonuses);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors du calcul des bonus."
                }
            };
        }
        
        return {
            effects: effects,
            bonuses: bonuses
        };
    }
}