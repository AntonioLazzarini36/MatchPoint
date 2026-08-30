-- Qué nivel le pareció a quien jugó contigo, y poder saltarse la reseña.
--
-- `assessedLevel` guarda **el nivel que esa persona cree que tienes**, no un
-- "correcto/mejor/peor". Es a propósito: el veredicto se deriva al leerlo,
-- comparándolo con el nivel que declaras ahora. Así, si cambias tu nivel, las
-- valoraciones antiguas se recolocan solas — quien dijo "intermedio" pasa de
-- estar de acuerdo a decir que te sobra nivel, sin tocar una fila. Guardar el
-- veredicto ya masticado lo congelaría contra un nivel que quizá ya no dices.
--
-- Cuando alguien responde "sí, era el nivel correcto" se guarda justamente el
-- nivel que esa persona declaraba en ese momento: "correcto" no es otra cosa
-- que estar de acuerdo con lo que pone.
ALTER TABLE "SessionFeedback" ADD COLUMN "assessedLevel" "SkillLevelValue";

-- Saltarse la reseña tiene que dejar rastro: sin fila, la quedada volvería a
-- salir en "¿qué tal fue?" para siempre, que es justo lo que se quería evitar
-- al saltarla. Con `skipped` la fila existe y no afirma nada — `played` queda
-- en false, así que no cuenta como partido jugado ni por asomo.
ALTER TABLE "SessionFeedback" ADD COLUMN "skipped" BOOLEAN NOT NULL DEFAULT FALSE;

-- Sin índice nuevo a propósito. La consulta que agrega esto no busca por
-- `userId` (ahí está quien *valora*, no el valorado): entra por las propuestas
-- de los matches de esa persona y filtra las filas ajenas, así que se apoya en
-- el índice de `proposalId` que ya existe. Un índice por `userId` aquí parece
-- que sirve y no lo tocaría nadie.
