---
name: github-publish
description: Publica un proyecto local a GitHub como repo público con README, LICENSE, .gitignore e install.sh generados automáticamente. También detecta y sube cambios en repos ya publicados. Use when the user says "publica en github", "sube a github", "publicar [proyecto] en github", "actualiza el repo de [proyecto]", "/github-publish", o quiere compartir un proyecto como open source.
---

# github-publish

Automatiza el proceso de publicar un proyecto local (Claude skill, script Python, o carpeta genérica) a GitHub como repo público. En invocaciones posteriores, detecta cambios y los sube automáticamente.

## Cuándo usar esta skill

Cuando el usuario quiere:
- Publicar por primera vez una skill o proyecto a GitHub como open source
- Actualizar un repo ya publicado con cambios locales
- Compartir su trabajo con la comunidad en forma de repo público

NO usar para:
- Manejar ramas, PRs, releases o colaboradores (eso se hace manualmente con comandos `gh` puntuales)
- Publicar a otras plataformas (npm, PyPI, GitLab)
- Borrar repos

## Pre-requisitos a verificar ANTES de ejecutar

Ejecutar primero:

```bash
gh auth status 2>&1 | grep -q "Logged in" && echo "OK_GH" || echo "FAIL_GH"
git --version >/dev/null 2>&1 && echo "OK_GIT" || echo "FAIL_GIT"
git config --global user.email >/dev/null 2>&1 && echo "OK_EMAIL" || echo "FAIL_EMAIL"
```

Si alguno retorna `FAIL_*`:
- `FAIL_GH` → decirle al usuario: "Necesitas autenticarte en GitHub primero. Corre: `gh auth login`". Abortar.
- `FAIL_GIT` → decirle: "Git no está instalado. Instálalo con: `brew install git`". Abortar.
- `FAIL_EMAIL` → auto-configurar con el email de `gh api user --jq .email`.

Obtener el usuario de GitHub para usarlo en todo el flujo:

```bash
GITHUB_USER=$(gh api user --jq .login)
```

## Paso 1: Identificar el proyecto a publicar

### Si el usuario nombró un proyecto específico

Buscar en orden:
1. `~/.claude/skills/<nombre>/` — si existe, es una Claude skill
2. `~/Documents/CLAUDE/projects/<nombre>/` — si existe, es un proyecto local
3. `~/Documents/CLAUDE/projects/github-repos/<nombre>/` — si existe, es un proyecto ya publicado (modo actualización)

Asignar a variable `SOURCE_DIR`.

### Si el usuario NO nombró un proyecto

Mostrarle una lista para que elija:

```bash
echo "📁 Skills instaladas en ~/.claude/skills/:"
ls ~/.claude/skills/ 2>/dev/null

echo ""
echo "📁 Proyectos en ~/Documents/CLAUDE/projects/:"
ls ~/Documents/CLAUDE/projects/ 2>/dev/null | grep -v "^github-repos$"

echo ""
echo "📁 Repos ya publicados en ~/Documents/CLAUDE/projects/github-repos/:"
ls ~/Documents/CLAUDE/projects/github-repos/ 2>/dev/null
```

Preguntar: "¿Qué quieres publicar? Dime el número o el nombre."

## Paso 2: Detectar tipo de proyecto

Escanear archivos en la carpeta fuente para determinar tipo:

```bash
# Claude skill: tiene SKILL.md en raíz o commands/*.md
if [ -f "$SOURCE_DIR/SKILL.md" ] || ls "$SOURCE_DIR"/commands/*.md 2>/dev/null | grep -q .; then
    TYPE="claude-skill"
# Python: tiene requirements.txt, setup.py, o pyproject.toml
elif [ -f "$SOURCE_DIR/requirements.txt" ] || [ -f "$SOURCE_DIR/setup.py" ] || [ -f "$SOURCE_DIR/pyproject.toml" ]; then
    TYPE="python"
else
    TYPE="generic"
fi

echo "Tipo detectado: $TYPE"
```

**Tipos combinados:** si el proyecto es `claude-skill` Y tiene `requirements.txt`, agregar `python.gitignore` a la mezcla además del `claude-skill.gitignore`.

## Paso 3: Determinar si es primera publicación o actualización

```bash
# Ubicación de destino según tipo:
if [ "$TYPE" = "claude-skill" ]; then
    DEST_DIR="$HOME/Documents/CLAUDE/projects/github-repos/$(basename $SOURCE_DIR)"
else
    # Para proyectos en projects/, el destino ES la misma carpeta (trabaja in-place)
    DEST_DIR="$SOURCE_DIR"
fi

# Si DEST_DIR existe y tiene .git con remote → modo ACTUALIZACIÓN
if [ -d "$DEST_DIR/.git" ] && git -C "$DEST_DIR" remote -v 2>/dev/null | grep -q "github.com"; then
    MODE="update"
else
    MODE="first_publish"
fi

echo "Modo: $MODE"
echo "Destino: $DEST_DIR"
```

---

## Flujo A: Primera publicación

Si `MODE=first_publish`, seguir estos pasos.

### Paso 4: Preguntar al usuario

Preguntar exactamente 2 cosas:

1. **Descripción corta** (1 línea, para GitHub + README):
   > "¿Descripción corta del repo? (1 línea, se verá en GitHub y en el README)"

2. **Visibilidad:**
   > "¿Público o privado? (Enter para público, default)"

Guardar respuestas en variables `DESCRIPTION` y `VISIBILITY` (default `public`).

### Paso 5: Preparar la carpeta de destino

Si el proyecto es Claude skill:

```bash
# Crear carpeta github-repos/ si no existe
mkdir -p "$HOME/Documents/CLAUDE/projects/github-repos"

# Copiar fuente → destino (usar rsync para respetar permisos)
rsync -a --exclude='.git' "$SOURCE_DIR/" "$DEST_DIR/"
```

Si es proyecto Python en `projects/`, trabajar in-place (no copiar).

### Paso 6: Generar archivos usando templates

**6a. Generar `.gitignore`:**

```bash
TEMPLATES="$HOME/.claude/skills/github-publish/templates/gitignore"

# Siempre incluir common.gitignore
cat "$TEMPLATES/common.gitignore" > "$DEST_DIR/.gitignore"

# Agregar específico del tipo
if [ "$TYPE" = "python" ]; then
    echo "" >> "$DEST_DIR/.gitignore"
    cat "$TEMPLATES/python.gitignore" >> "$DEST_DIR/.gitignore"
elif [ "$TYPE" = "claude-skill" ]; then
    echo "" >> "$DEST_DIR/.gitignore"
    cat "$TEMPLATES/claude-skill.gitignore" >> "$DEST_DIR/.gitignore"
    # Si además tiene requirements.txt, agregar python también
    if [ -f "$DEST_DIR/requirements.txt" ]; then
        echo "" >> "$DEST_DIR/.gitignore"
        cat "$TEMPLATES/python.gitignore" >> "$DEST_DIR/.gitignore"
    fi
fi
```

**6b. Generar `LICENSE`:**

```bash
YEAR=$(date +%Y)
AUTHOR=$(git config --global user.name)
sed -e "s/{{YEAR}}/$YEAR/g" -e "s/{{AUTHOR}}/$AUTHOR/g" \
    "$HOME/.claude/skills/github-publish/templates/LICENSE-MIT" > "$DEST_DIR/LICENSE"
```

**6c. Generar `install.sh`** (solo si `TYPE=python` o `TYPE=claude-skill`):

```bash
if [ "$TYPE" = "python" ] || [ "$TYPE" = "claude-skill" ]; then
    INSTALL_TEMPLATE="$HOME/.claude/skills/github-publish/templates/install/${TYPE}.sh"
    PROJECT_NAME="$(basename $DEST_DIR)"
    sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$INSTALL_TEMPLATE" > "$DEST_DIR/install.sh"
    chmod +x "$DEST_DIR/install.sh"
fi
```

**6d. Generar `README.md`:**

Claude lee el template `README-base.md` y el proyecto analizado, luego rellena placeholders:

- `{{EMOJI}}` — escoger emoji apropiado según tipo de proyecto (📥 download, 🧹 cleanup, 🚀 launcher, 🛠️ tools, 📊 data, etc.)
- `{{PROJECT_NAME}}` — nombre de la carpeta
- `{{DESCRIPTION}}` — respuesta del usuario
- `{{FEATURES}}` — analizar SKILL.md/código y generar lista de 4-6 bullet points en español
- `{{USE_CASES}}` — 3-4 casos de uso en bullets
- `{{REQUIREMENTS}}` — detectar desde requirements.txt / package.json / pyproject.toml. Para Claude skills: mencionar Claude Code como requisito.
- `{{INSTALL_INSTRUCTIONS}}` — generar comandos `git clone + cd + ./install.sh` (o solo clone si no hay install.sh). Formato bash con code block.
- `{{USAGE}}` — ejemplo de uso básico (detectar del SKILL.md si es claude-skill: el comando `/<nombre>`)
- `{{OPTIONAL_FAQ}}` — incluir sección `## ❓ FAQ` solo si hay preguntas relevantes; si no, omitir completamente
- `{{GITHUB_USER}}` — ya está en la variable `$GITHUB_USER`

Para generar este contenido, Claude debe:
1. Leer `$SOURCE_DIR/SKILL.md` si existe
2. Leer `$SOURCE_DIR/README.md` si existe (para heredar contenido si ya había uno)
3. Listar los archivos principales del proyecto
4. Detectar dependencias en `requirements.txt` o `package.json`

Usar Write tool para crear el README final en `$DEST_DIR/README.md` con el contenido rellenado.

### Paso 7: Validaciones de seguridad

Antes de mostrar el preview, ejecutar:

```bash
cd "$DEST_DIR"

# Escanear secretos en archivos de texto a subir
FOUND_SECRETS=$(grep -rE "(api[_-]?key[\"'\s:=]+[a-zA-Z0-9_-]{20,}|sk-[a-zA-Z0-9]{40,}|ghp_[a-zA-Z0-9]{36}|-----BEGIN .* PRIVATE KEY-----)" \
    --exclude-dir=venv --exclude-dir=node_modules --exclude-dir=.git \
    --include="*.py" --include="*.js" --include="*.json" --include="*.md" --include="*.txt" \
    -l 2>/dev/null)

# Archivos grandes (>10MB)
LARGE_FILES=$(find . -size +10M -not -path "./venv/*" -not -path "./.git/*" -not -path "./node_modules/*" 2>/dev/null)

# Verificar carpeta vacía
FILES_COUNT=$(find "$DEST_DIR" -type f -not -path "*/.*" -not -path "*/venv/*" -not -path "*/node_modules/*" | wc -l)
if [ "$FILES_COUNT" -eq 0 ]; then
    echo "❌ La carpeta está vacía. Nada que publicar."
    exit 1
fi
```

### Paso 8: Preview y confirmación

Mostrar al usuario un resumen con formato claro:

```
📋 Archivos que se subirán a GitHub:
  ✅ README.md (2.1 KB)
  ✅ LICENSE (1.1 KB)
  [...listar archivos que NO están en .gitignore]

⚠️  Warnings:
  [listar archivos con secrets sospechosos y archivos >10MB, si hay]

❌ Excluidos por .gitignore:
  [listar patrones excluidos principales]

Nombre del repo: github.com/<GITHUB_USER>/<NOMBRE>
Descripción: <DESCRIPTION>
Visibilidad: <VISIBILITY>

¿Confirmas subir a GitHub? (s/n)
```

Si el usuario dice "n" → limpiar archivos auto-generados solo si la skill los creó (guardar flags antes de generar: `README_EXISTED`, `LICENSE_EXISTED`, `GITIGNORE_EXISTED`, `INSTALL_EXISTED`), y abortar con mensaje amigable.

### Paso 9: Publicar

Si el usuario confirma:

```bash
cd "$DEST_DIR"

REPO_NAME=$(basename "$DEST_DIR")

# Verificar si repo existe en GitHub con ese nombre
if gh repo view "$GITHUB_USER/$REPO_NAME" >/dev/null 2>&1; then
    echo "⚠️  El repo '$REPO_NAME' ya existe en tu cuenta GitHub."
    echo "Opciones:"
    echo "  1. Usar otro nombre"
    echo "  2. Conectar al existente (si no tienes cambios conflictivos)"
    echo "  3. Abortar"
    # Manejar según respuesta del usuario
fi

# Inicializar git si no existe
if [ ! -d ".git" ]; then
    git init
fi

# Add, commit, publish
git add .
git commit -m "Initial commit: $REPO_NAME"

gh repo create "$REPO_NAME" \
    --"$VISIBILITY" \
    --source=. \
    --push \
    --description "$DESCRIPTION"

# Abrir en navegador
gh repo view --web
```

### Paso 10: Mostrar resultado final

```
✅ Publicado: https://github.com/<GITHUB_USER>/<REPO_NAME>
Copia local: <DEST_DIR>

Instalación para usuarios:
  git clone https://github.com/<GITHUB_USER>/<REPO_NAME>.git
  cd <REPO_NAME>
  ./install.sh
```

Si el proyecto es Claude skill, preguntar además:

> "¿Quieres que esta skill también quede instalada en tu Mac (~/.claude/skills/) para usarla tú también? (s/n)"

Si s, ejecutar `$DEST_DIR/install.sh` para completar instalación local.

---

## Flujo B: Actualización de proyecto ya publicado

Si `MODE=update`, seguir estos pasos.

### Paso 4b: Sincronizar desde la fuente (solo Claude skills)

Si el proyecto es Claude skill:

```bash
# Copiar archivos de ~/.claude/skills/<nombre>/ → github-repos/<nombre>/
# Respetar .gitignore existente en destino (excluyendo archivos ignorados)
rsync -a --exclude='.git' \
    --exclude='venv' --exclude='node_modules' --exclude='__pycache__' \
    --exclude='downloaded' --exclude='cookies' \
    "$SOURCE_DIR/" "$DEST_DIR/"
```

Para proyectos Python, el usuario edita directamente en `$DEST_DIR` (que es la misma ubicación que `$SOURCE_DIR` en estos casos), así que no hay que copiar nada.

### Paso 5b: Mostrar cambios detectados

```bash
cd "$DEST_DIR"

# Ver qué cambió
CHANGES=$(git status --short)

if [ -z "$CHANGES" ]; then
    echo "No hay cambios detectados. El repo ya está actualizado."
    exit 0
fi

# Mostrar cambios
git status --short
```

Formatear output para el usuario:
- `M ` → ✏️ (modificado)
- `??` → ➕ (nuevo)
- `D ` → ❌ (borrado)

### Paso 6b: Proponer mensaje de commit

Analizar los cambios con `git diff --stat` y generar un mensaje corto que describa la esencia:

Ejemplos:
- 1 archivo nuevo + README actualizado → "Add <nombre-archivo>"
- Varios archivos modificados → "Update <resumen de cambios>"
- Archivos borrados → "Remove <nombre>"
- Mix de cambios → "Update and add <resumen>"

Mostrar al usuario:

```
Mensaje sugerido: "Add shredder module"
(Presiona Enter para aceptar, o escribe tu propio mensaje)
```

Leer respuesta del usuario:
- Si responde vacío o "s" → usar el sugerido
- Si escribe algo → usar lo que escribió

### Paso 7b: Commit y push

```bash
cd "$DEST_DIR"
git add .
git commit -m "$COMMIT_MESSAGE"
git push
```

### Paso 8b: Mostrar confirmación

```
✅ Actualizado en GitHub
Últimos commits: https://github.com/<GITHUB_USER>/<REPO_NAME>/commits/main
```

---

## Manejo de errores y edge cases

### Repo con nombre ya existente en GitHub

Ver Paso 9 — manejar con las 3 opciones.

### Carpeta vacía

Ver Paso 7 — abortar antes del preview.

### git push falla por cambios remotos

En el flujo B (actualización), si `git push` falla con "rejected":

```
⚠️  GitHub tiene cambios que no están en tu copia local.
    Esto pasa si editaste archivos directamente en github.com.

    Ejecuta manualmente: git pull --rebase
    Luego invoca /github-publish de nuevo.
```

### Usuario cancela en el preview

Si el usuario responde "n" en la confirmación del Paso 8:

```bash
# Limpiar solo archivos que la skill creó (no los que existían antes)
[ "$README_EXISTED" = "no" ] && rm -f "$DEST_DIR/README.md"
[ "$LICENSE_EXISTED" = "no" ] && rm -f "$DEST_DIR/LICENSE"
[ "$GITIGNORE_EXISTED" = "no" ] && rm -f "$DEST_DIR/.gitignore"
[ "$INSTALL_EXISTED" = "no" ] && rm -f "$DEST_DIR/install.sh"

echo "Publicación cancelada. No se hizo ningún cambio en GitHub."
```

### gh no autenticado

Si al inicio falla el chequeo de `gh auth status`:

```
❌ Necesitas autenticarte en GitHub primero.

Ejecuta en terminal:
  gh auth login

Y luego invoca /github-publish de nuevo.
```

## Cierre

Al terminar (exitoso o no), siempre:

- Mostrar resumen conciso de lo que pasó
- Si publicó: dar el hipervínculo al repo (formato markdown clickeable)
- Si hubo error: dar pasos claros para resolver
- Si fue actualización: mostrar link al commit nuevo

Usar hipervínculos markdown con rutas relativas al workspace cuando referencies archivos locales (ej: `[SKILL.md](projects/github-repos/<nombre>/SKILL.md)`).
