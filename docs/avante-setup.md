# Avante.nvim Enhanced Setup Guide

## Overview
This document describes the enhanced Avante.nvim configuration with multiple providers, advanced features, and custom keybindings.

## Key Improvements Made

### 1. Fixed Configuration Errors
- **Model Name**: Fixed incorrect Claude model name from `claude-sonnet-4-20250514` to `claude-3-5-sonnet-20241022`
- **Environment Variables**: Added fallback environment variable support
- **Dependencies**: Ensured all required dependencies are properly configured

### 2. Multiple AI Providers
- **Claude**: Primary provider with optimized settings
- **OpenAI**: Backup provider with GPT-4o
- **Gemini**: Google's AI model support
- **Azure OpenAI**: Enterprise Azure integration

### 3. Enhanced Features
- **Auto Suggestions**: Enabled for better productivity
- **Image Support**: Added img-clip.nvim for image pasting
- **Markdown Rendering**: Enhanced markdown display
- **Security**: File exclusion patterns for sensitive data
- **Performance**: Optimized memory usage and response caching

## Environment Variables Required

Set these environment variables in your shell configuration:

```bash
# Claude API
export ANTHROPIC_API_KEY="your-claude-api-key"
export AVANTE_ANTHROPIC_API_KEY="your-claude-api-key"  # Alternative

# OpenAI API (optional)
export OPENAI_API_KEY="your-openai-api-key"

# Gemini API (optional)
export GEMINI_API_KEY="your-gemini-api-key"

# Claude Code OAuth (optional, for advanced features)
export CLAUDE_CODE_OAUTH_TOKEN="your-oauth-token"
export AVANTE_CLAUDE_CODE_OAUTH_TOKEN="your-oauth-token"  # Alternative
```

## Custom Keybindings

### Main Commands
- `<leader>aa` - Ask Avante (normal/visual mode)
- `<leader>ar` - Refresh Avante
- `<leader>ae` - Edit with Avante (normal/visual mode)
- `<leader>ac` - Open Avante Chat
- `<leader>af` - Focus Avante window
- `<leader>at` - Toggle Avante

### Provider Switching
- `<leader>apc` - Switch to Claude provider
- `<leader>apo` - Switch to OpenAI provider
- `<leader>apg` - Switch to Gemini provider

### Quick Actions
- `<leader>aq` - Quick ask
- `<leader>as` - Save context and ask
- `<leader>afi` - Edit instructions file

### Diff Operations
- `<leader>ado` - Show diff
- `<leader>ada` - Apply diff
- `<leader>adr` - Reject diff

### Templates
- `<leader>atr` - Code review template
- `<leader>ato` - Optimization template
- `<leader>atd` - Documentation template
- `<leader>att` - Test template

### History and Export
- `<leader>ah` - Show history
- `<leader>acl` - Clear chat
- `<leader>aex` - Export conversation

## Configuration Highlights

### Window Configuration
```lua
windows = {
    position = "right",  -- right, left, top, bottom
    wrap = true,
    width = 30,  -- % based on available width
    sidebar_header = {
        enabled = true,
        align = "center",
        rounded = true,
    },
},
```

### Security Settings
```lua
security = {
    exclude_patterns = {
        "*.env*", "*.key", "*.pem", "*.p12", "*.pfx",
        "*secret*", "*password*",
    },
    confirm_large_files = true,
    max_file_size = 1024 * 1024,  -- 1MB
},
```

### Performance Optimizations
```lua
performance = {
    max_history_size = 50,
    cache_responses = true,
    debounce_ms = 300,
},
```

## Usage Tips

### 1. Project Instructions
Create an `avante.md` file in your project root with specific instructions:
```markdown
# Project Instructions
This is a [language] project using [framework].
Follow [coding standards] and [patterns].
```

### 2. Provider Selection
Switch providers based on your needs:
- **Claude**: Best for code analysis and complex reasoning
- **OpenAI**: Good general-purpose AI
- **Gemini**: Alternative with different strengths

### 3. Context Management
- Use visual selection to provide specific code context
- Save current buffer context with `<leader>as`
- Clear chat history when switching contexts

### 4. Diff Workflow
1. Ask for code changes
2. Review the diff with `<leader>ado`
3. Apply with `<leader>ada` or reject with `<leader>adr`

## Troubleshooting

### Common Issues
1. **API Key Not Set**: Ensure environment variables are properly configured
2. **Model Not Found**: Check if the model name is correct and available
3. **Network Issues**: Verify internet connection and API endpoints
4. **Performance**: Adjust `debounce_ms` and `max_history_size` if needed

### Debug Commands
- `<leader>adb` - Show current configuration
- `<leader>adl` - Show logs and messages
- Set `debug = true` in config for verbose logging

## Dependencies
All required dependencies are automatically installed:
- `nvim-lua/plenary.nvim`
- `MunifTanjim/nui.nvim`
- `folke/snacks.nvim`
- `HakonHarnes/img-clip.nvim`
- `MeanderingProgrammer/render-markdown.nvim`
- `echasnovski/mini.icons`

## Updates and Maintenance
- Keep Avante.nvim updated with `:Lazy update`
- Check for new model releases and update configuration
- Monitor API usage and costs
- Review and update security patterns regularly
