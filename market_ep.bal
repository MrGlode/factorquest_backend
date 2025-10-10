import ballerina/http;
import ballerina/log;

service /market on new http:Listener(server_port + 4) {
    resource function get prices(@http:Header string Authorization) returns MarketPricesResponse|http:Unauthorized|http:InternalServerError {
        
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

        MarketPrice[]|error prices = getMarketPrices(payload.sub);
        
        if prices is error {
            log:printError("Erreur lors de la récupération des prix", 'error = prices);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération des prix."
                }
            };
        }

        return {
            prices: prices
        };
    }

    resource function post sell(@http:Header string Authorization, SellResourceRequest req) returns SellResourceResponse|http:BadRequest|http:Unauthorized|http:InternalServerError {
        
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

        // Validation de la requête
        if req.quantity <= 0 {
            return <http:BadRequest>{
                body: {
                    message: "La quantité doit être supérieure à 0."
                }
            };
        }

        SellResourceResponse|error result = sellResource(payload.sub, req.resourceId, req.quantity);
        
        if result is error {
            log:printError("Erreur lors de la vente", 'error = result);
            
            // Vérifier le type d'erreur
            string errorMsg = result.message();
            if errorMsg.includes("Insufficient resources") {
                return <http:BadRequest>{
                    body: {
                        message: errorMsg
                    }
                };
            }
            
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la vente de la ressource."
                }
            };
        }

        return result;
    }

    resource function get orders(@http:Header string Authorization) returns SpecialOrderResponse|http:Unauthorized|http:InternalServerError {
        
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

        SpecialOrder[]|error orders = getActiveSpecialOrders(payload.sub);
        
        if orders is error {
            log:printError("Erreur lors de la récupération des commandes", 'error = orders);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération des commandes."
                }
            };
        }

        return {
            orders: orders
        };
    }

    resource function post orders/[string orderId]/fulfill(@http:Header string Authorization) returns FulfillOrderResponse|http:BadRequest|http:NotFound|http:Unauthorized|http:InternalServerError {
        
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

        FulfillOrderResponse|error result = fulfillSpecialOrder(payload.sub, orderId);
        
        if result is error {
            log:printError("Erreur lors de la livraison de la commande", 'error = result);
            
            string errorMsg = result.message();
            
            // Ordre non trouvé
            if errorMsg.includes("Order not found") {
                return <http:NotFound>{
                    body: {
                        message: "Commande non trouvée."
                    }
                };
            }
            
            // Ordre déjà complété ou expiré
            if errorMsg.includes("already completed") || errorMsg.includes("expired") {
                return <http:BadRequest>{
                    body: {
                        message: errorMsg
                    }
                };
            }
            
            // Ressources insuffisantes
            if errorMsg.includes("Insufficient") {
                return <http:BadRequest>{
                    body: {
                        message: errorMsg
                    }
                };
            }
            
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la livraison de la commande."
                }
            };
        }

        // Si la réponse indique un échec (success: false)
        if !result.success {
            return <http:BadRequest>{
                body: result
            };
        }

        return result;
    }

    resource function get transactions(@http:Header string Authorization, int 'limit = 50) returns TransactionsResponse|http:BadRequest|http:Unauthorized|http:InternalServerError {
        
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

        // Valider la limite
        if 'limit < 1 || 'limit > 100 {
            return <http:BadRequest>{
                body: {
                    message: "La limite doit être entre 1 et 100."
                }
            };
        }

        Transaction[]|error transactions = getTransactions(payload.sub, 'limit);
        
        if transactions is error {
            log:printError("Erreur lors de la récupération des transactions", 'error = transactions);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la récupération des transactions."
                }
            };
        }

        return {
            transactions: transactions,
            total: transactions.length()
        };
    }

    resource function post orders/generate(@http:Header string Authorization) returns SpecialOrder|http:Unauthorized|http:InternalServerError {
        
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

        SpecialOrder|error 'order = generateSpecialOrder(payload.sub);
        
        if 'order is error {
            log:printError("Erreur lors de la génération de la commande", 'error = 'order);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la génération de la commande."
                }
            };
        }

        return 'order;
    }

    resource function put prices/update(@http:Header string Authorization) returns http:Ok|http:Unauthorized|http:InternalServerError {
        
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

        error? result = updateMarketPrices(payload.sub);
        
        if result is error {
            log:printError("Erreur lors de la mise à jour des prix", 'error = result);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de la mise à jour des prix."
                }
            };
        }

        return <http:Ok>{
            body: {
                message: "Prix du marché mis à jour avec succès."
            }
        };
    }

    resource function post initializePrices(@http:Header string Authorization) returns http:Ok|http:Unauthorized|http:InternalServerError {
        
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

        error? result = initializeMarketPrices(payload.sub);
        
        if result is error {
            log:printError("Erreur lors de l'initialisation des prix", 'error = result);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur lors de l'initialisation des prix."
                }
            };
        }

        return <http:Ok>{
            body: {
                message: "Prix du marché initialisés avec succès."
            }
        };
    }
}