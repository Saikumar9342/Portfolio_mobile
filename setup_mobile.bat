@echo off
echo Setting up Portfolio Mobile...
echo Generating Android support files...
call flutter create --platforms android .
if %errorlevel% neq 0 (
    echo Failed to create Android project.
    pause
    exit /b %errorlevel%
)
echo.

echo Installing dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo Failed to get dependencies. Please ensure Flutter is installed and in PATH.
    pause
    exit /b %errorlevel%
)
echo.

echo Running app...
call flutter run
pause
