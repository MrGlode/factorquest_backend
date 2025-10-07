import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;

service /auth on new http:Listener(server_port +1) {
    resource function post register(RegisterRequest req) returns AuthResponse|http:BadRequest|http:Conflict|http:InternalServerError {
        if req.username.length() < 3 {
            return <http:BadRequest>{
                body:  {
                    message: "Le nom d'utilisateur doit contenir au moins 3 caractères."
                }
            };
        }

        if !isValidEmail(req.email) {
            return <http:BadRequest>{
                body:  {
                    message: "Adresse e-mail invalide."
                }
            };
        }

        if !isValidPassword(req.password) {
            return <http:BadRequest>{
                body:  {
                    message: "Le mot de passe doit contenir au moins 8 caractères, une lettre, un chiffre et un caractère spécial."
                }
            };
        }

        User|error existingEmail = findUserByEmail(req.email);
        if existingEmail is User {
            return <http:Conflict>{
                body: {
                    message: "Cet email est déjà utilisé."
                }
            };
        }

        string|error passwordHash = hashPassword(req.password);
        if passwordHash is error {
            log:printError("Erreur lors du hachage du mot de passe", 'error = passwordHash);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        time:Utc now = time:utcNow();
        User newUser = {
            id: uuid:createType1AsString(),
            username: req.username,
            email: req.email,
            passwordHash: passwordHash,
            displayName: req.displayName,
            createdAt: now,
            updatedAt: now,
            isActive: true,
            roles: ["player"]
        };

        User|error savedUser = createUser(newUser);
        if savedUser is error {
            log:printError("Erreur lors de la création de l'utilisateur", 'error = savedUser);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        string|error accesToken = generateAccessToken(savedUser);
        string|error refreshToken = generateRefreshToken(savedUser);
        if accesToken is error || refreshToken is error {
            log:printError("Erreur lors de la génération des tokens");
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        PlayerProfile|error playerProfile = createPlayerProfile(savedUser.id);
        if playerProfile is error {
            log:printError("Erreur lors de la création du profil joueur", 'error = playerProfile);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        return {
            accessToken: accesToken,
            refreshToken: refreshToken,
            expiresIn: jwt_expiresIn,
            user: toPublicUser(savedUser)
        };
    }

    resource function post login(LoginRequest req) returns AuthResponse|http:Unauthorized|http:InternalServerError {
        User|error user = findUserByUsername(req.username);
        if user is error {
            return <http:Unauthorized>{
                body: {
                    message: "Identifiants invalides."
                }
            };
        }

        boolean|error isValid = verifyPassword(req.password, user.passwordHash);
        if isValid is error || !isValid {
            return <http:Unauthorized>{
                body: {
                    message: "Identifiants invalides."
                }
            };
        }

        if !user.isActive {
            return <http:Unauthorized>{
                body: {
                    message: "Compte utilisateur désactivé."
                }
            };
        }

        string|error accessToken = generateAccessToken(user);
        string|error refreshToken = generateRefreshToken(user);
        if accessToken is error || refreshToken is error {
            log:printError("Erreur lors de la génération des tokens");
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        error? recordLoginResult = recordLogin(user.id);
        if recordLoginResult is error {
            log:printError("Erreur lors de l'enregistrement de la connexion", 'error = recordLoginResult);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        return {
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: jwt_expiresIn,
            user: toPublicUser(user)
        };
    }

    resource function post refresh(RefreshTokenRequest req) returns AuthResponse|http:Unauthorized|http:InternalServerError {
        JwtPayload|error payload = validateToken(req.refreshToken);
        if payload is error {
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide ou expiré."
                }
            };
        }

        User|error user = findUserById(payload.sub);
        if user is error {
            return <http:Unauthorized>{
                body: {
                    message: "Utilisateur non trouvé."
                }
            };
        }

        if !user.isActive {
            return <http:Unauthorized>{
                body: {
                    message: "Compte utilisateur désactivé."
                }
            };
        }

        string|error accessToken = generateAccessToken(user);
        string|error refreshToken = generateRefreshToken(user);
        if accessToken is error || refreshToken is error {
            log:printError("Erreur lors de la génération des tokens");
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        return {
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: jwt_expiresIn,
            user: toPublicUser(user)
        };
    }

    resource function get me(@http:Header string Authorization) returns UserPublic|http:Unauthorized|http:InternalServerError {
        string token = Authorization.substring(7);
        JwtPayload|error payload = validateToken(token);
        if payload is error {
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide ou expiré."
                }
            };
        }

        User|error user = findUserById(payload.sub);
        if user is error {
            return <http:Unauthorized>{
                body: {
                    message: "Utilisateur non trouvé."
                }
            };
        }

        return toPublicUser(user);
    }

    resource function post 'forgot\-password(ForgotPasswordRequest req) returns http:Ok|http:BadRequest|http:InternalServerError {
        if !isValidEmail(req.email) {
            return <http:BadRequest>{
                body:  {
                    message: "Adresse e-mail invalide."
                }
            };
        }

        User|error user = findUserByEmail(req.email);
        if user is error {
            return <http:Ok>{
                body: {
                    message: "Si cet email est enregistré, un lien de réinitialisation a été envoyé."
                }
            };
        }

        string resetToken = generatePasswordResetToken();
        time:Utc expiresAt = time:utcAddSeconds(time:utcNow(), 3600);

        PasswordResetToken token = {
            userId: user.id,
            token: resetToken,
            expiresAt: expiresAt,
            used: false
        };

        error? result = createPasswordResetToken(token);
        if result is error {
            log:printError("Erreur lors de la création du token de réinitialisation");
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        //TODO Envoyer l'email avec le token de réinitialisation
        log:printInfo("Token de réinitialisation (à envoyer par email): " + resetToken);

        return <http:Ok>{
            body: {
                message: "Si cet email est enregistré, un lien de réinitialisation a été envoyé."
            }
        };
    }

    resource function post 'reset\-password(ResetPasswordRequest req) returns http:Ok|http:BadRequest|http:InternalServerError {
        if !isValidPassword(req.newPassword) {
            return <http:BadRequest>{
                body:  {
                    message: "Le mot de passe doit contenir au moins 8 caractères, une lettre, un chiffre et un caractère spécial."
                }
            };
        }

        PasswordResetToken|error token = findPasswordResetToken(req.token);
        if token is error {
            return <http:BadRequest>{
                body: {
                    message: "Token invalide ou expiré."
                }
            };
        }

        if token.used || <int>time:utcDiffSeconds(time:utcNow(), token.expiresAt) > 0 {
            return <http:BadRequest>{
                body: {
                    message: "Token invalide ou expiré."
                }
            };
        }

        string|error passwordHash = hashPassword(req.newPassword);
        if passwordHash is error {
            log:printError("Erreur lors du hachage du mot de passe");
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        token.used = true;
        error? result = updatePasswordResetToken(token.id ?: "", token);
        if result is error {
            log:printError("Erreur lors de la mise à jour du token de réinitialisation");
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        error? updateResult = updateUserPassword(token.userId, passwordHash);
        if updateResult is error {
            log:printError("Erreur lors de la mise à jour du mot de passe");
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        error? markResult = markPasswordResetTokenUsed(req.token);
        if markResult is error {
            log:printError("Erreur lors du marquage du token de réinitialisation comme utilisé");
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        return <http:Ok>{
            body: {
                message: "Mot de passe réinitialisé avec succès."
            }
        };
    }
}