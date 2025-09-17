📒 FNotes
Современное десктопное приложение для заметок с поддержкой:
- Организации заметок в папки
- Системы тегов
- Переключения между светлой и тёмной темой (с сохранением состояния)
- Локального хранения данных через Hive

   
Приложение написано на Flutter и работает на:
 - macOS
 -  Windows (нужна сборка на Windows с Visual Studio)
 - Linux (экспериментально)

—————

Установка и запуск:

1. Склонировать репозиторий:
git clone https://github.com/username/fnotes.git cd fnotes

2. Установить зависимости:
flutter pub get

3. Запуск в режиме разработки:
flutter run -d macos
или
flutter run -d windows

—————


Сборка релиза:

macOS:

flutter build macos --release

Собранное приложение появится в:
build/macos/Build/Products/Release/


Windows:
Убедитесь, что установлен Visual Studio с Desktop Development C++
flutter build windows --release

Собранное приложение появится в:
build/windows/x64/runner/Release/

—————

Технологии:

•	Flutter 

•	Hive 

•	Hive Flutter
