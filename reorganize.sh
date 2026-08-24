#!/usr/bin/env bash
#
# reorganize.sh — restructure Librelane-Procedure-and-Usage into a clean layout.
#
# Run this from the ROOT of your cloned repo:
#     cd path/to/Librelane-Procedure-and-Usage
#     bash reorganize.sh
#
# It uses `git mv` so file history is preserved (blame/log still work).
# Review the diff before committing.

set -euo pipefail

echo "==> Creating new directories"
mkdir -p docs assets/images

echo "==> Moving the standalone guides into docs/"
git mv Installation.md       docs/installation.md
git mv Usage.md              docs/usage.md
git mv "Writing Config.md"   docs/writing-config.md   # note: kills the space in the name

echo "==> Moving loose screenshots into assets/images/"
for n in 1 2 3 4 5 6 7 8; do
  if [ -f "${n}.png" ]; then
    git mv "${n}.png" "assets/images/${n}.png"
  fi
done

echo "==> Lowercasing the examples directory"
# Two-step rename so it works on case-insensitive filesystems (macOS/Windows).
if [ -d "Examples" ]; then
  git mv Examples examples-tmp
  git mv examples-tmp examples
fi

echo
echo "==> Done moving files. Next steps (manual):"
echo "  1. Replace README.md with the new index version."
echo "  2. Add docs/concepts.md (the timing/DRC/LVS/debugging content)."
echo "  3. Fix image links: any markdown that referenced e.g. ![](1.png)"
echo "     now needs ![](assets/images/1.png) — find them with:"
echo "         grep -rn '\\.png' --include='*.md' ."
echo "  4. Fix the old config link: anything pointing to 'Writing%20Config.md'"
echo "     now points to 'docs/writing-config.md'. Find it with:"
echo "         grep -rn 'Writing' --include='*.md' ."
echo "  5. Add a LICENSE (GitHub: Add file -> Create new file -> type 'LICENSE'"
echo "     -> pick a template. MIT is the usual choice for docs like this)."
echo "  6. Stage and commit:"
echo "         git add -A"
echo "         git commit -m 'Restructure: docs/, examples/, assets/, slim README'"
echo "         git push"
