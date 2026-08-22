-- Cerrar el bucle. Hasta ahora toda la app llevaba a una quedada acordada y
-- ahi se acababa: una propuesta ACCEPTED cuya fecha ya paso se quedaba igual
-- que el dia que se acepto. Nadie preguntaba si se jugo.
--
-- Eso dejaba tres agujeros: el nivel auto-declarado no se corregia nunca
-- (siendo "encuentra a alguien de tu nivel" la promesa central), el rating
-- calculado era imposible por falta de partidos que puntuar, y la app no
-- tenia ningun motivo para volver a abrirse despues de quedar.

-- Quien gano. Solo tiene sentido en deportes con marcador: al correr se
-- queda en NULL, y por eso la columna es nullable en vez de tener un valor
-- "no aplica" que habria que ignorar en todas las consultas.
CREATE TYPE "SessionOutcome" AS ENUM ('WON', 'LOST', 'TIED');

-- Una fila por persona y quedada, no una por quedada: cada uno contesta por
-- su cuenta y hay que poder detectar que uno dice que se jugo y el otro no.
-- Ademas es la forma natural de guardar el resultado desde el punto de vista
-- de cada jugador (WON de uno es LOST del otro), que es justo lo que come un
-- sistema de rating.
CREATE TABLE "SessionFeedback" (
    "id"          TEXT PRIMARY KEY,
    "proposalId"  TEXT NOT NULL REFERENCES "Proposal"("id") ON DELETE CASCADE,
    "userId"      TEXT NOT NULL REFERENCES "User"("id") ON DELETE CASCADE,
    -- false = la quedada no llego a ocurrir. Se guarda igual, y no se borra
    -- la propuesta: que alguien falle a lo acordado es informacion, no un
    -- error que haya que limpiar.
    "played"      BOOLEAN NOT NULL,
    "outcome"     "SessionOutcome",
    -- La senal de confianza que de verdad importa para reencontrarse.
    -- Nullable porque no se pregunta si no se jugo.
    "wouldRepeat" BOOLEAN,
    "createdAt"   TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Se contesta una vez. El upsert por esta clave permite corregir la
    -- respuesta sin acumular filas.
    UNIQUE ("proposalId", "userId")
);

-- La consulta caliente es "que quedadas mias siguen sin contestar", que
-- parte del usuario.
CREATE INDEX "SessionFeedback_userId_idx" ON "SessionFeedback"("userId");
