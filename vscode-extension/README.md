# Collie LSP Test Extension

Test extension for developing and testing collie-lsp.

## Setup

```bash
# Install dependencies
npm install

# Compile TypeScript
npm run compile
```

## Testing

1. Open this folder in VS Code
2. Press F5 to launch Extension Development Host
3. Create a test .y file
4. Verify LSP features work (diagnostics, completion, etc.)

## Configuration

In the Extension Development Host, you can configure:

```json
{
  "collie-lsp.serverPath": "/path/to/collie-lsp",
  "collie-lsp.trace.server": "verbose"
}
```

## Viewing LSP Communication

Open Output panel (View > Output) and select "Collie LSP" from the dropdown.
