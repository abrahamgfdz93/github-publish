# 🚀 github-publish

Skill de Claude Code que publica un proyecto local a GitHub como repo público — con README, LICENSE, `.gitignore` e `install.sh` generados automáticamente. En invocaciones posteriores detecta cambios y los sube por ti. Al terminar, ofrece crear o actualizar la documentación en Confluence automáticamente.

## ✨ Qué hace

- Publica por primera vez cualquier carpeta local (Claude skill, script Python o proyecto genérico) como repo de GitHub.
- **Detecta el tipo de proyecto** (claude-skill / python / genérico) y adapta los archivos que genera.
- Genera automáticamente **README.md**, **LICENSE (MIT)**, **`.gitignore`** e **`install.sh`** a partir de plantillas.
- **Escanea secretos** (API keys, tokens, llaves privadas) y archivos grandes antes de subir, y te muestra un preview para confirmar.
- **Modo actualización:** en repos ya publicados detecta los cambios, propone el mensaje de commit y hace push.
- **Integración Confluence:** al terminar pregunta si quieres crear o actualizar la página de documentación en Confluence automáticamente.

## 🎯 Casos de uso

- Compartir una skill o herramienta con la comunidad como open source.
- Subir cambios a un repo que ya publicaste sin acordarte de los comandos de git.
- Empaquetar un proyecto local con documentación e instalador listos para otros.
- Mantener GitHub y Confluence sincronizados sin esfuerzo extra.

## 📋 Requisitos

- [Claude Code](https://docs.claude.com/claude-code) instalado.
- [`gh` (GitHub CLI)](https://cli.github.com/) autenticado (`gh auth login`).
- `git` instalado.
- Conector Atlassian activo en Claude Code (para la integración con Confluence, opcional).

## 🚀 Instalación

```bash
git clone https://github.com/abrahamgfdz93/github-publish.git
cd github-publish
./install.sh
```

## 💻 Uso

Abre Claude Code y escribe:

```
/github-publish
```

La skill te preguntará qué publicar, una descripción corta y si el repo es público o privado. Al confirmar el preview, crea el repo y hace push. Al final ofrece crear o actualizar la página en Confluence.

## 📄 Licencia

[MIT](LICENSE) — úsalo libremente, modifícalo, distribúyelo.

---

Hecho con ☕ por [@abrahamgfdz93](https://github.com/abrahamgfdz93)
