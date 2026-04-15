@echo off
cd /d C:\Users\Student\Nchat\nchat_fix
echo ========== Flutter Cleaning Project ==========
flutter clean
echo ========== Getting Pub Packages ==========
flutter pub get
echo ========== Flutter Doctor Report ==========
flutter doctor -v
pause
