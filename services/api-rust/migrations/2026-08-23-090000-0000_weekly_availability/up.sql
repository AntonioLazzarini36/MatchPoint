-- La disponibilidad pasa de seis franjas gruesas a un horario semanal, y de
-- ser un criterio de orden a ser una **referencia**.
--
-- El planteamiento anterior estaba mal por dos motivos. Uno: seis casillas
-- ("mañanas entre semana") son demasiado gruesas para decidir nada — quien
-- puede los martes por la mañana y quien puede los jueves por la mañana
-- marcaban lo mismo y no coinciden nunca. Y dos, mas importante: cuando
-- puede jugar alguien **es variable**, asi que usarlo para ordenar el feed
-- convierte una aproximacion en una verdad que no es.
--
-- Lo que si resuelve el problema real es enseñarselo a quien va a proponer:
-- "esta persona suele tener libre los martes por la tarde" evita que le
-- propongas un lunes a las 8 y os pegueis tres mensajes para descubrirlo.

-- Mapa de bits de 21 posiciones: 7 dias x 3 franjas.
--
--   bit = dia * 3 + franja
--   dia:    0 = lunes ... 6 = domingo
--   franja: 0 = mañana, 1 = tarde, 2 = noche
--
-- Un entero y no un array de enum de 21 valores: la lista de nombres seria
-- ruido, y lo unico que se hace con esto es pintarlo y compararlo. 21 bits
-- entran de sobra en un INTEGER.
ALTER TABLE "Profile" DROP COLUMN availability;
DROP TYPE "AvailabilitySlot";

ALTER TABLE "Profile"
    ADD COLUMN availability INTEGER NOT NULL DEFAULT 0;
