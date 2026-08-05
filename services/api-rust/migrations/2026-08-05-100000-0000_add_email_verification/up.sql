-- Verificación de email: hasta ahora cualquiera podía registrarse con el
-- correo de otra persona, porque nadie comprobaba que le perteneciera.

-- NULL = sin verificar. Se guarda la fecha y no un booleano porque
-- "cuándo lo verificó" es dato útil (soporte, auditoría) y el booleano se
-- deduce igual.
ALTER TABLE "User" ADD COLUMN "emailVerifiedAt" TIMESTAMPTZ;

-- Códigos de 6 dígitos de un solo uso. Se guarda el SHA-256 del código,
-- no el código: si alguien lee la base, no puede verificar cuentas
-- ajenas. SHA-256 y no bcrypt porque el espacio es de un millón de
-- combinaciones y lo que lo protege es el TTL corto y el límite de
-- intentos, no el coste de hashear — y bcrypt aquí sólo añadiría latencia
-- a cada intento.
CREATE TABLE "EmailVerification" (
    "id"        TEXT PRIMARY KEY,
    "userId"    TEXT NOT NULL REFERENCES "User"("id") ON DELETE CASCADE,
    "codeHash"  TEXT NOT NULL,
    "expiresAt" TIMESTAMPTZ NOT NULL,
    "attempts"  INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Se busca siempre por usuario (el código más reciente sin caducar).
CREATE INDEX "EmailVerification_userId_idx" ON "EmailVerification"("userId");
