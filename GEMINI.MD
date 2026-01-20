# Project Context: Gemini CLI Tooling

## Tech Stack
- Language: Python 3.10+
- Key Libraries: `google-genai`, `click` or `typer` (for CLI), `rich` (for UI)
- API: Gemini 1.5 Flash (default) / Pro

## Development Rules
- **Formatting:** Always use `rich` for terminal output (tables, panels).
- **Error Handling:** Every API call must be wrapped in a try-except block with clear user-facing errors.
- **Documentation:** Use Google-style docstrings for all functions.
- **Security:** Never hardcode API keys. Use `os.getenv("GEMINI_API_KEY")`.

## Workflow
1. Use `Perceive -> Plan -> Implement` pattern.
2. Before writing code, explain the logic in 2-3 sentences.
3. Test every CLI command with a mock response before finalizing.