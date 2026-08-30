-- Recuperar la contraseña olvidada.
--
-- Hasta ahora no existía: quien perdía la contraseña perdía la cuenta para
-- siempre, porque tampoco había ningún otro modo de entrar. Con cero usuarios
-- no se notaba; con un club dentro, sí.
--
-- Mismo diseño que EmailVerification, y por los mismos motivos:
--   * se guarda el SHA-256 del código, nunca el código;
--   * caduca pronto (lo que protege seis dígitos es el plazo y el límite de
--     intentos, no el coste de hashear);
--   * un contador de intentos para que no se pueda probar a lo bruto.
--
-- ON DELETE CASCADE como el resto: borrar la cuenta se lo lleva todo.
CREATE TABLE "PasswordReset" (
    id          TEXT PRIMARY KEY,
    "userId"    TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
    "codeHash"  TEXT NOT NULL,
    "expiresAt" TIMESTAMPTZ NOT NULL,
    attempts    INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX "PasswordReset_userId_idx" ON "PasswordReset"("userId");
