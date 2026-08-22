-- A qué viene cada uno. Hasta ahora esto se preguntaba en el onboarding
-- ("Jugar por nivel" / "Conocer gente" / "Ambos") y la frase elegida se
-- guardaba **como la bio**: el resultado era que en toda la app sólo existían
-- tres descripciones posibles, idénticas para todo el mundo, y la bio dejaba
-- de servir para lo único que sirve una bio.
--
-- Son dos datos distintos y ahora van separados: la intención es
-- estructurada (se puede enseñar como etiqueta y algún día filtrar por ella)
-- y la bio vuelve a ser texto libre de la persona.
CREATE TYPE "Intention" AS ENUM ('COMPETE', 'TRAIN', 'LEARN', 'FUN');

-- Nullable: los perfiles anteriores a esto no la tienen, y no declararla es
-- una respuesta válida.
ALTER TABLE "Profile" ADD COLUMN intention "Intention";

-- Recupera la intención de quien ya pasó por el onboarding viejo, leyéndola
-- de la bio donde quedó atrapada, y **vacía esas bios**: no las escribió
-- nadie, son la etiqueta de un botón. Dejarlas ahí significaría que medio
-- Discovery sigue con la misma frase de descripción.
UPDATE "Profile" SET
    intention = CASE
        WHEN bio = 'Jugar por nivel' THEN 'COMPETE'::"Intention"
        WHEN bio = 'Conocer gente'  THEN 'FUN'::"Intention"
        WHEN bio = 'Ambos'          THEN 'LEARN'::"Intention"
    END,
    bio = NULL
WHERE bio IN ('Jugar por nivel', 'Conocer gente', 'Ambos');
