@echo off
echo ============================================
echo   RideWind 应用启动脚本
echo ============================================
echo.

cd /d "%~dp0"

echo [1/3] 清理构建缓存...
flutter clean

echo.
echo [2/3] 获取依赖...
flutter pub get

echo.
echo [3/3] 运行应用...
flutter run

pause

