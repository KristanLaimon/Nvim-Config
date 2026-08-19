# 🎯 C# / .NET / Blazor Development Suite

[← Back to Wiki Index](../index.md) | [← Back to Languages Overview](../languages.md)

KrsVim provides a full **C#**, **.NET**, and **Blazor** development environment, supporting solution files (`.sln`), project files (`.csproj`), NuGet package management, formatting with CSharpier, and debugging via `netcoredbg`.

---

## 🛠️ Toolchain Summary

| Feature | Tool / Package | Details |
| :--- | :--- | :--- |
| **Language Server (LSP)** | `omnisharp`, `lemminx` | `omnisharp` for C# source files; `lemminx` for XML validation in `.csproj`, `.props`, `.targets` |
| **Formatters (Conform)** | `csharpier` | Code formatting for `.cs` files |
| **Treesitter Parsers** | `c_sharp` | Syntax highlighting for C# and Razor/Blazor constructs |
| **Autocompletion** | `blink.cmp` | IntelliSense completion, Roslyn analyzers, and auto-imports |
| **Debug Adapter (DAP)** | `netcoredbg` (`coreclr`) | Debug adapter for .NET Core / .NET 8/9, Blazor Server, and CLI apps |
| **Project Utilities** | `dotnet_creator`, `nuget` | Interactive project template creator and NuGet package search |

---

## 🧰 Ex Commands & Command Palette Actions

Accessible via **Command Palette** (`<C-S-p>` / `:CommandPalette`):

* `:DotnetNew` – Interactive `.NET` project creator (`dotnet new` template picker).
* `:NugetManager` – Open NuGet package manager to search and add package references to `.csproj`.
* `:FormatDocument` – Format active `.cs` file using CSharpier or LSP fallback.
* `:LanguageManager` – Install or uninstall the C# / .NET language bundle.

---

## 🐞 Debugger Profiles (`<F5>`)

1. **`🎯 Launch .NET Assembly DLL (C#)`**: Auto-detects or prompts for compiled `.dll` inside `bin/Debug/net8.0/` or `net9.0/`.
2. **`🌐 Launch & Debug Blazor Server App`**: Launches Blazor Server application DLL with `ASPNETCORE_ENVIRONMENT=Development`.
3. **`🔌 Attach to Running .NET / Blazor Process`**: Pick running `dotnet` process ID to attach `netcoredbg`.
