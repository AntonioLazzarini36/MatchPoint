-- Tokens de FCM para poder mandar notificaciones push. Hasta ahora la app
-- sólo se enteraba de un mensaje o una propuesta sondeando con la app
-- abierta: cerrada, no llegaba nada.

-- Una fila por dispositivo, no por usuario: la misma persona puede tener el
-- móvil y una tablet, y quiere que le suene en los dos. Y al revés, un mismo
-- dispositivo puede pasar por varias cuentas (te deslogueas y entra otro), de
-- ahí que el token sea único y su "userId" se pueda reasignar en vez de
-- acumular filas — si no, el dueño anterior seguiría recibiendo los mensajes
-- de la cuenta nueva.
CREATE TABLE "DeviceToken" (
    "id"        TEXT PRIMARY KEY,
    "userId"    TEXT NOT NULL REFERENCES "User"("id") ON DELETE CASCADE,
    "token"     TEXT NOT NULL UNIQUE,
    "platform"  TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- El envío siempre parte de "a quién hay que avisar", así que se busca por
-- usuario para recoger todos sus dispositivos.
CREATE INDEX "DeviceToken_userId_idx" ON "DeviceToken"("userId");
