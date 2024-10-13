# Запуск 

## GUI
`dub --root=./gui run -- ./project-name`

## CLI
Интерактивный режим:  
`dub --root=./cli run -- ./project-name --god -i`

Получение элемента по XPath:  
`dub --root=cli run -- project-name/common/database.xml --xpath '//aux/log/host/@port'`

### Опции
bool iteractive;    /// Интерактивный ввод  
bool god;   /// Создать бог-xml документ из всех. Если нет, ввод только одного файла.  
bool human; /// Человеко-читаемый вывод TODO:  
string[] paths; /// Путь до xml файлов, Если папка - рекурсивно обработает  
string param;   /// путь к настройке просто набор имен узлов через разделитель  
string xpath;   /// Найти что-то по XPath  
bool verbose;  

## Юниттестирование

`dub test`

# Версии
dub - DUB version 1.38.0, built on Jun 11 2024  
dmd - DMD64 D Compiler v2.109.0