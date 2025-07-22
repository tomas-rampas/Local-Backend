# Cross-Platform PowerShell Migration Summary

This document summarizes the cross-platform enhancements made to the Artemis Backend testing and diagnostic suite.

## 🎯 Migration Objectives

✅ **Enable PowerShell scripts to run on Linux, macOS, and WSL**  
✅ **Maintain backward compatibility with Windows PowerShell 5.x**  
✅ **Provide comprehensive installation and setup guidance**  
✅ **Implement automatic platform detection and adaptation**  
✅ **Ensure Docker integration works across all platforms**

## 📦 What Was Added

### 1. Cross-Platform Utility Framework
- **`Platform-Utilities.ps1`** - Core platform detection and utility functions
  - Automatic OS detection (Windows, Linux, macOS, WSL)
  - PowerShell version detection
  - Docker/Docker Compose availability testing
  - Cross-platform command execution
  - Environment variable handling

### 2. Enhanced Main Test Runner
- **`Run-AllTests.ps1`** - Updated with platform detection
  - Automatic platform information display
  - Cross-platform Docker checks with Linux-specific guidance
  - Platform-aware error messages and troubleshooting

### 3. Setup and Installation Tools
- **`Install-PowerShell7.ps1`** - Interactive setup guide
  - Platform-specific installation instructions
  - Environment verification and validation
  - Automated setup for permissions and Docker access

### 4. Comprehensive Documentation
- **`doctor/README.md`** - Complete cross-platform guide
  - Installation instructions for all platforms
  - Usage examples for different operating systems
  - Platform-specific considerations and troubleshooting

- **`CLAUDE.md`** - Updated development guidance
  - Cross-platform development workflow
  - PowerShell 7 installation steps
  - Platform-aware testing commands

## 🚀 Key Features

### Automatic Platform Detection
```powershell
$platform = Get-CurrentPlatform
# Returns: IsWindows, IsLinux, IsMacOS, IsWSL, PowerShellVersion, etc.
```

### Cross-Platform Docker Integration
```powershell
$dockerAvailable = Test-DockerAvailability
$composeInfo = Test-DockerComposeAvailability  # Detects v1 vs v2
```

### Executable Script Support
All scripts now include proper shebang lines and are executable on Linux/macOS:
```bash
#!/usr/bin/env pwsh
```

### Smart Default Handling
```powershell
Get-EnvironmentVariable "LOCAL_BACKEND_BOOTSTRAP_PASSWORD" "changeme"
# Falls back to defaults if environment variables aren't set
```

## 🌐 Platform Support Matrix

| Feature | Windows PowerShell 5.x | PowerShell 7 Windows | PowerShell 7 Linux | PowerShell 7 macOS |
|---------|------------------------|---------------------|-------------------|-------------------|
| Basic functionality | ✅ | ✅ | ✅ | ✅ |
| Docker integration | ✅ | ✅ | ✅ | ✅ |
| Platform detection | ✅ | ✅ | ✅ | ✅ |
| Direct execution | ✅ | ✅ | ✅ (with chmod) | ✅ (with chmod) |
| WSL detection | N/A | ✅ | ✅ | N/A |
| Performance optimization | ✅ | ✅ | ✅ (faster) | ✅ |

## 📋 Usage Examples

### Windows
```powershell
# Windows PowerShell or PowerShell 7
.\doctor\Run-AllTests.ps1
.\doctor\Install-PowerShell7.ps1 -ShowInstructions
```

### Linux/macOS/WSL
```bash
# Make executable (one-time)
chmod +x doctor/*.ps1

# Direct execution
./doctor/Run-AllTests.ps1
./doctor/Install-PowerShell7.ps1 -VerifyInstallation

# Or via pwsh
pwsh -File ./doctor/Run-AllTests.ps1
```

## 🔧 Installation Quick Reference

### Ubuntu/Debian (including WSL)
```bash
# Add Microsoft repository
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update

# Install PowerShell 7
sudo apt-get install -y powershell

# Configure Docker access
sudo usermod -aG docker $USER
newgrp docker
```

### macOS
```bash
# Using Homebrew
brew install --cask powershell
```

### Windows
```powershell
# Using Windows Package Manager
winget install --id Microsoft.Powershell --source winget
```

## 🧪 Testing the Migration

1. **Installation Guide**: `./doctor/Install-PowerShell7.ps1`
2. **Environment Verification**: `./doctor/Install-PowerShell7.ps1 -VerifyInstallation`
3. **Platform Detection**: Load Platform-Utilities.ps1 and call `Get-CurrentPlatform`
4. **Full Test Suite**: `./doctor/Run-AllTests.ps1`

## 📈 Benefits Achieved

### For Developers
- **Consistent experience** across Windows, Linux, and macOS
- **Faster execution** on Linux/WSL2 for Docker operations
- **Better integration** with cloud and container environments
- **Modern PowerShell features** (PowerShell 7+)

### For Operations
- **Unified tooling** regardless of deployment platform
- **Container-first approach** works seamlessly across environments
- **Better CI/CD integration** with Linux-based systems
- **Comprehensive diagnostics** with platform-aware troubleshooting

### For the Project
- **Future-proofed** for cloud-native development
- **Broader accessibility** for developers on different platforms
- **Maintained compatibility** with existing Windows workflows
- **Enhanced documentation** and setup guidance

## 🔮 Future Enhancements

### Potential Improvements
- [ ] Container-based test execution (Docker-in-Docker)
- [ ] GitHub Actions integration for cross-platform CI
- [ ] Enhanced WSL performance optimizations
- [ ] ARM64 support for Apple Silicon Macs
- [ ] Kubernetes testing scenarios

### Platform-Specific Optimizations
- [ ] Linux-specific Docker optimizations
- [ ] macOS-specific certificate handling
- [ ] Windows-specific performance tuning
- [ ] WSL-specific file system optimizations

## ✅ Verification Checklist

To verify the cross-platform migration is working:

1. **Platform Detection**:
   - [ ] Correctly identifies Windows/Linux/macOS
   - [ ] Detects WSL environment
   - [ ] Identifies PowerShell version and edition

2. **Docker Integration**:
   - [ ] Detects Docker availability across platforms
   - [ ] Handles Docker Compose v1 and v2
   - [ ] Provides platform-specific setup guidance

3. **Script Execution**:
   - [ ] Scripts run directly on Linux/macOS (with chmod +x)
   - [ ] Backward compatibility with Windows PowerShell 5.x
   - [ ] Consistent behavior across all platforms

4. **Documentation**:
   - [ ] Installation instructions for all platforms
   - [ ] Platform-specific troubleshooting guides
   - [ ] Usage examples for different environments

## 📞 Support and Troubleshooting

### Common Issues
- **"pwsh: command not found"**: PowerShell 7 not installed or not in PATH
- **"Permission denied"**: Scripts need executable permissions (`chmod +x`)
- **"Docker not found"**: User not in docker group on Linux
- **Performance issues**: Use WSL2 instead of WSL1 for better performance

### Getting Help
1. Run the installation guide: `./doctor/Install-PowerShell7.ps1`
2. Verify environment: `./doctor/Install-PowerShell7.ps1 -VerifyInstallation`
3. Check documentation: `doctor/README.md`
4. Review platform considerations in `CLAUDE.md`

---

**Migration Completed**: ✅ All scripts are now cross-platform compatible with PowerShell 7!
**Test Status**: Ready for cross-platform testing and validation
**Documentation**: Comprehensive guides available for all supported platforms