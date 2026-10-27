local _, ns = ...

-- Textos del arranque de la aplicación y de sus comandos (Core/Init.lua, Core/App.lua).
ns.Locale.Register("esES", {
  ["app.schema_newer"] = "Los datos guardados fueron escritos por una versión más reciente del addon (esquema %d). "
    .. "Forever Achievements queda desactivado para protegerlos. Actualiza el addon para volver a usarlo.",
  ["app.start_failed"] = "no se pudo iniciar: %s",
  ["forget.usage"] = "uso: /fach forget <nombre del personaje>",
  ["forget.unknown"] = "Ningún personaje conocido se llama '%s'.",
  ["forget.current"] = "'%s' es el personaje que estás jugando; entra con otro para olvidarlo.",
  ["forget.ambiguous"] = "Hay varios personajes conocidos llamados '%s'. "
    .. "Usa uno de estos identificadores (/fach forget <id>):",
  ["forget.done"] = "Se olvidó a '%s' y sus logros.",
})
