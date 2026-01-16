# Setup Guide

This guide explains how to set up pgctl using the automated setup script.

## Quick Start

```bash
# Run the setup script
./setup.sh
```

This will:
1. Detect your operating system
2. Install PostgreSQL client (psql)
3. Install gum (optional but recommended)
4. Create config.env from the example
5. Verify the installation

## Setup Options

### Install Everything (Recommended)

```bash
./setup.sh
```

### Install Only PostgreSQL Client

If you already have gum or don't want the interactive UI features:

```bash
./setup.sh --skip-gum
```

### Install Only Gum

If you already have PostgreSQL client installed:

```bash
./setup.sh --skip-psql
```

### Non-Interactive Mode

For automated setups or CI/CD:

```bash
./setup.sh -y
```

or

```bash
./setup.sh --non-interactive
```

## Supported Platforms

### macOS
- Uses Homebrew for installation
- Requires Homebrew to be installed first

### Linux

**Debian/Ubuntu:**
- PostgreSQL: via `apt`
- Gum: via Charm's apt repository

**Fedora/RHEL/CentOS:**
- PostgreSQL: via `yum/dnf`
- Gum: via Charm's yum repository

**Arch/Manjaro:**
- PostgreSQL: via `pacman`
- Gum: via `pacman`

**Alpine:**
- PostgreSQL: via `apk`
- Gum: via `apk`

## Post-Installation

After running the setup script:

1. **Edit Configuration**
   ```bash
   nano config.env
   # Update PGHOST, PGPORT, PGADMIN as needed
   ```

2. **Set Admin Password**
   ```bash
   export PGPASSWORD=your_admin_password
   ```

3. **Run pgctl**
   ```bash
   ./pgctl
   ```

## Verification

The setup script automatically verifies the installation at the end. You can manually verify by running:

```bash
# Check PostgreSQL client
psql --version

# Check gum
gum --version

# Test pgctl
./pgctl help
```

## Troubleshooting

### Homebrew Not Found (macOS)

Install Homebrew first:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Permission Errors (Linux)

The script uses `sudo` for system package installations. Make sure your user has sudo privileges.

### Package Manager Not Found

For systems not covered by the script, install manually:

**PostgreSQL Client:**
- Download from: https://www.postgresql.org/download/

**Gum:**
- Download from: https://github.com/charmbracelet/gum/releases
- Or install via Go: `go install github.com/charmbracelet/gum@latest`
- Or use Nix: `nix-env -iA nixpkgs.gum`

## What Gets Installed?

### PostgreSQL Client (psql)

The PostgreSQL command-line client allows pgctl to:
- Connect to PostgreSQL servers
- Execute SQL commands
- Create databases, users, and manage permissions

### Gum (Optional)

Gum provides:
- Interactive menus
- Beautiful styled output
- User input prompts
- Progress indicators

**Note:** pgctl works without gum, but provides a better experience with it installed.

## Minimal Installation

If you only need the core functionality without interactive features:

```bash
# Install only PostgreSQL client
./setup.sh --skip-gum

# Or manually
# macOS: brew install postgresql@16
# Ubuntu: sudo apt install postgresql-client
```

## CI/CD Integration

For automated environments:

```bash
# Non-interactive installation
./setup.sh --non-interactive

# Or install specific components only
./setup.sh --skip-gum -y
```

## Next Steps

After successful setup, see:

- **[README.md](README.md)** for:
  - Command reference
  - Usage examples
  - Configuration options
  - Security best practices

- **[CONTRIBUTING.md](CONTRIBUTING.md)** if you want to:
  - Contribute to the project
  - Report bugs
  - Request features
  - Understand the codebase
