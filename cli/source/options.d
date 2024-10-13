module options;

import std.getopt;
import std.stdio;
import core.stdc.stdlib : exit;

bool iteractive;    /// Интерактивный ввод
bool god;   /// Создать бог-xml документ из всех. Если нет, ввод только одного файла.
bool human; /// Человеко-читаемый вывод TODO:
string[] paths; /// Путь до xml файлов, Если папка - рекурсивно обработает
string param;   /// путь к настройке просто набор имен узлов через разделитель
string xpath;   /// Найти что-то по XPath
bool verbose;

private GetoptResult helpInfo;

void begin (ref string[] args, string[] delegate(ref string[]) post)
{
    helpInfo = getopt(args,
        config.passThrough,
        "interactive|i", "Интерактивный ввод", &iteractive,
        "god|g", "Создать бог-xml документ из всех. Если нет, ввод только одного файла.", &god,
        "human", "Человеко-читаемый вывод", &human,
        "param", "Найти по пути к настройке: набор имен узлов через разделитель", &param,
        "xpath", "Найти что-то по XPath", &xpath,
        "verbose|v", &verbose
    );

    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter("Some information about the program.", helpInfo.options);
        exit(0);
    }

    paths = post(args);

    if (verbose)
    {
        writefln("Args: %s", args);
        writeln("Options values:");
        static foreach (var; [ "iteractive", "god", "human", "paths", "param", "xpath", "verbose"])
        {
            mixin(`writefln("\t%s = %s;", var, `, var,`);`);
        }
    }

}