-- Cuando puede jugar cada uno.
--
-- Faltaba por completo: la app filtraba por nivel y por distancia, pero no
-- sabia nada de horarios. Dos personas del mismo nivel a dos kilometros no
-- juegan nunca si una puede los martes por la mañana y la otra los sabados —
-- y no lo descubrian en el perfil, sino despues del match, escribiendose, y
-- tras dos o tres propuestas fallidas. En la practica el horario impide mas
-- partidos que el nivel y la distancia juntos.

-- Franjas gruesas y no un calendario a proposito. Lo que hace falta saber es
-- "¿podemos coincidir?", y para eso sobra con seis casillas: pedir mas
-- detalle solo consigue que nadie lo rellene, y un perfil vacio no ordena
-- nada.
CREATE TYPE "AvailabilitySlot" AS ENUM (
    'WEEKDAY_MORNING',
    'WEEKDAY_AFTERNOON',
    'WEEKDAY_EVENING',
    'WEEKEND_MORNING',
    'WEEKEND_AFTERNOON',
    'WEEKEND_EVENING'
);

-- Array y no tabla aparte: es una lista corta y cerrada que siempre se lee
-- entera con el perfil, igual que `sports`. Vacio = no lo ha dicho, y quien
-- no lo ha dicho no se penaliza en el orden (mismo criterio que el filtro de
-- genero: vaciar el feed de alguien por un dato que falta es peor fallo que
-- ordenarlo un poco peor).
ALTER TABLE "Profile"
    ADD COLUMN availability "AvailabilitySlot"[] NOT NULL DEFAULT '{}';
