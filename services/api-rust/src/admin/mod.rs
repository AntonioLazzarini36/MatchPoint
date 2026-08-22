//! Cola de moderación.
//!
//! Existe porque `POST /users/:id/report` llevaba desde siempre escribiendo
//! en una tabla que **nadie leía**: si alguien denunciaba acoso, la denuncia
//! entraba en un cajón que no se abría nunca. Con usuarios reales eso deja de
//! ser deuda técnica, y además Google Play exige moderación explícita para
//! apps con contenido de usuarios.
//!
//! **Por qué una clave en una cabecera y no un rol de administrador:** un rol
//! obliga a añadir el concepto de permisos al modelo de datos, a decidir
//! quién lo concede y a una pantalla para gestionarlo — todo para un
//! operador, que hoy es una persona. Una variable de entorno es la
//! autorización más simple que resuelve el problema de verdad, y el día que
//! haya un equipo de moderación se sustituye sin tocar la cola.
//!
//! Sin `ADMIN_API_KEY` configurada, estos endpoints responden 404: no existe
//! una puerta que abrir. Es a propósito — dejarlos abiertos "porque no hay
//! clave" sería peor que no tenerlos.

pub mod controller;
pub mod service;
