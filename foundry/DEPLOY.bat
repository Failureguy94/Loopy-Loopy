@echo off
REM Deployment Helper Script for Windows
REM This script helps deploy all contracts and generate artifacts

echo ========================================
echo Loopy-Loopy Contract Deployment
echo ========================================
echo.

REM Check if forge is installed
where forge >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Forge not found!
    echo Please install Foundry first:
    echo   1. Download foundryup from https://getfoundry.sh/
    echo   2. Run: foundryup
    echo.
    pause
    exit /b 1
)

echo Step 1: Compiling contracts...
echo ========================================
forge build
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Compilation failed!
    pause
    exit /b 1
)
echo.

echo Step 2: Deploy to Sepolia
echo ========================================
echo Make sure you have set these environment variables:
echo   - SEPOLIA_RPC
echo   - SEPOLIA_PRIVATE_KEY
echo   - CALLBACK_SENDER_ADDR
echo.
set /p CONTINUE="Continue with Sepolia deployment? (y/n): "
if /i not "%CONTINUE%"=="y" (
    echo Deployment cancelled.
    pause
    exit /b 0
)

forge script script/DeployAll.s.sol:DeploySepoliaAll --rpc-url %SEPOLIA_RPC% --broadcast -vvv
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Sepolia deployment failed!
    pause
    exit /b 1
)
echo.

echo ========================================
echo Sepolia deployment complete!
echo.
echo IMPORTANT: Copy the deployed addresses and set these environment variables:
echo   set LOOPER_VAULT_ADDR=^<address^>
echo   set SHIELD_VAULT_ADDR=^<address^>
echo   set PROTECTION_EXECUTOR_ADDR=^<address^>
echo   set ORIGIN_LOOPER_ADDR=^<address^>
echo.
pause

echo Step 3: Deploy to Reactive Kopli
echo ========================================
echo Make sure you have set these environment variables:
echo   - REACTIVE_RPC
echo   - REACTIVE_PRIVATE_KEY
echo   - SYSTEM_CONTRACT_ADDR
echo   - LOOPER_VAULT_ADDR (from previous step)
echo   - SHIELD_VAULT_ADDR (from previous step)
echo   - PROTECTION_EXECUTOR_ADDR (from previous step)
echo.
set /p CONTINUE="Continue with Reactive deployment? (y/n): "
if /i not "%CONTINUE%"=="y" (
    echo Deployment cancelled.
    pause
    exit /b 0
)

forge script script/DeployAll.s.sol:DeployReactiveAll --rpc-url %REACTIVE_RPC% --broadcast -vvv
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Reactive deployment failed!
    pause
    exit /b 1
)
echo.

echo ========================================
echo All deployments complete!
echo.
echo Step 4: Update addresses.json
echo ========================================
echo Please update the following file with your deployed addresses:
echo   ..\frontend\src\constants\addresses.json
echo.
pause

echo Step 5: Generate Artifacts
echo ========================================
node script/generateArtifacts.js
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Artifact generation failed!
    echo Make sure Node.js is installed.
    pause
    exit /b 1
)
echo.

echo ========================================
echo SUCCESS! All done!
echo ========================================
echo.
echo Generated files:
echo   - Frontend ABIs: ..\frontend\src\constants\abi\
echo   - Frontend addresses: ..\frontend\src\constants\addresses.json
echo   - Backend config: ..\backend\contracts.json
echo.
echo Next steps:
echo   1. Start your backend with the updated contracts.json
echo   2. Test all features (looper bot, unwind, liquidation protection)
echo.
pause
