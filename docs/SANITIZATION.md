# Sanitization and provenance

The reference tree retains the original PowerShell procedures, loops, conditionals, runspace construction, API calls, and numeric protocol literals. Each reference has a `.ps1.txt` suffix and a header identifying it as historical text.

The preparation replaced operational string literals, interpolated strings, here-strings, comments, filesystem bindings, and network bindings. A small explicit allowlist preserves protocol labels, command modes, common HTTP values, and framework type names. This conservative approach also replaces some harmless presentation text; placeholders are not a functional configuration format.

Original HTML interfaces were omitted from this cleanup because they mix presentation code with operational configuration and references. The separately maintained SitebossHub demonstration preserves and validates a sanitized subset of the original custom Canvas UI. Operational CSV, SQLite and Access data, spreadsheets, key files, logs, process identifiers, shortcuts, DLLs, icons, and audio assets are excluded from this tree.

`source-manifest.json` records original source hashes and the hashes of the sanitized references. Hashes identify the selected source and its derivative; they do not make the original deployment safe or prove that the programs were correct.

Original files were preserved privately, never executed, and Git history was not rewritten. Earlier published commits can still contain the material removed from the current tree. Credential validity was not tested. Any historical access material still in use requires replacement independently of source cleanup.
