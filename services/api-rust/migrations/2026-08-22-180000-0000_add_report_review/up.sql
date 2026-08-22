-- Los reportes se escribian en una tabla que nadie leia jamas: si alguien
-- denunciaba acoso, la denuncia entraba en un cajon que no se abria nunca.
-- Ademas Google Play exige moderacion explicita para apps con contenido de
-- usuarios, asi que tambien bloqueaba la publicacion.
--
-- Esto le da a la tabla lo minimo para que sea una cola de trabajo de verdad:
-- saber que esta sin mirar, y poder cerrar lo mirado dejando constancia.

-- NULL = sin revisar. Fecha y no booleano, por lo mismo que
-- `User.emailVerifiedAt`: "cuando se reviso" es dato util para responder a
-- quien denuncio, y el booleano se deduce.
ALTER TABLE "Report" ADD COLUMN "reviewedAt" TIMESTAMPTZ;

-- Que se decidio. Texto libre a proposito: una lista cerrada de motivos se
-- queda corta el primer dia y lo que hace falta aqui es que quede escrito.
ALTER TABLE "Report" ADD COLUMN "reviewNote" TEXT;

-- La consulta de la cola es siempre "lo que falta por mirar, lo mas viejo
-- primero". El indice parcial solo cubre esas filas, que son las pocas que
-- importan: las revisadas se acumulan para siempre y no se consultan.
CREATE INDEX "Report_pending_idx"
    ON "Report"("createdAt")
    WHERE "reviewedAt" IS NULL;
