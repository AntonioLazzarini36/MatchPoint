//! Contadores para los badges de la barra de navegación.
//!
//! Existe como módulo propio (en vez de colgar de `me/`) porque cruza
//! chats y propuestas: es una vista agregada, no una propiedad del perfil.
//! Devuelve solo números, a propósito — el cliente ya sabe pedir el
//! detalle cuando el usuario entra a la pestaña correspondiente, y esto
//! se llama en bucle mientras la app está abierta.
pub mod controller;
pub mod service;
