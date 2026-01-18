# Building EmberType

This guide provides instructions for building EmberType from source.

## Prerequisites

- macOS 14.0 or later
- Xcode (latest version recommended)
- Git
- Apple Silicon Mac (M1/M2/M3/M4)

## Quick Start (Recommended)

The easiest way to build EmberType is using the included Makefile:

```bash
# Clone the repository
git clone https://github.com/EmberVista/EmberType.git
cd EmberType

# Build everything
make all

# Or build and run
make dev
```

### Available Commands

| Command | Description |
|---------|-------------|
| `make check` | Verify all required tools are installed |
| `make whisper` | Build whisper.cpp XCFramework |
| `make setup` | Prepare whisper framework for linking |
| `make build` | Build the Xcode project |
| `make run` | Launch the built app |
| `make dev` | Build and run (development workflow) |
| `make all` | Complete build process |
| `make clean` | Remove build artifacts |
| `make help` | Show all commands |

## Manual Build

If you prefer manual control:

### 1. Build whisper.cpp

```bash
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
./build-xcframework.sh
```

This creates `build-apple/whisper.xcframework`.

### 2. Build EmberType

```bash
git clone https://github.com/EmberVista/EmberType.git
cd EmberType
```

Add the whisper.xcframework to the project:
- Drag `whisper.xcframework` into Xcode's project navigator, or
- Add it in "Frameworks, Libraries, and Embedded Content"

Then build:
- **Cmd+B** to build
- **Cmd+R** to run

## Architecture

EmberType is built exclusively for **Apple Silicon** (arm64). Intel Macs are not supported due to whisper.cpp optimization requirements.

## Troubleshooting

**Build fails with framework errors:**
- Clean build folder (Cmd+Shift+K)
- Ensure whisper.xcframework is properly linked
- Check Xcode and macOS versions

**App crashes on launch:**
- Verify you're on an Apple Silicon Mac
- Check that all permissions are granted (Accessibility, Microphone)

**whisper.cpp build fails:**
- Ensure Xcode Command Line Tools are installed: `xcode-select --install`
- Check you have enough disk space (~2GB needed)

## Development Notes

- Use Debug configuration for development
- Release builds are optimized for Apple Silicon
- Run tests before submitting PRs

## Need Help?

- Check [GitHub Issues](https://github.com/EmberVista/EmberType/issues)
- Create a new issue with build logs
- Email: contact@embertype.com
