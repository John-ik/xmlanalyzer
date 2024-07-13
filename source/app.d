debug import std.logger;

import std.stdio;
import std.file;
import std.path;
import std.algorithm : map, joiner, filter, copy;

import std.range : walkLength, take, ElementType;
import std.typecons : Flag, Yes, No;
import std.meta : AliasSeq;
import std.traits : isInstanceOf;

import dxml.dom;

import dxml.xpath;
import set;

import xmlutils;




int main(string[] args)
{
	infof("Args: %s", args);
	
	string[] xmlFiles = getAllXmlFrom(args[1..$]);

	info(xmlFiles);

	DOMEntity!string[] xmlDocs = parseAll(xmlFiles);

	// writeln(xmlDocs);

	DOMEntity!string godXml = makeGodXml(xmlDocs);

	
	//BUG: так как я убрал @property и добавил ref к .children() то возможны UB позиции текста.
	// В идеале, если необходима позиция то нужно пересобирать дерево по новой.
	// дерево закинул в writeXmlFromDOM и на вход в parseDOM и вау-ля. Дерево пересобрано
	// godXml.children()[1].children() ~= xmlDocs[1].children()[0].children()[0];
	// Пофикшено? restruct()

	string output = writeXmlFromDOM(godXml);
	writeln(godXml);
	writeln(output);

	// assert(godXml["//cfg/@filename"] == godXml["/././*/..//cfg/@filename"]);
	string line;
	write("Enter XPath: ");
	while ((line = stdin.readln()) !is null) {
		writefln("%(>- %s\n%)", godXml[line]);
		write("Enter XPath: ");
	}

	// writeln(map!(a => a.text)(godXml["/cfg/things//text()"][]));

	// God-xml
	

	// // God-xml
	// EntityRange!(MyEntityTemplate) godXml;
	// foreach (string path; xmlFiles)
	// {
	// 	auto a = readText(path).parseXML!simpleXML().ifThrown(entityNone());
	// 	if (a == entityNone())
	// 		continue;
		
	// }
	// auto xmlDocs = xmlFiles
	// 				.map!(a => readText(a).parseXML!simpleXML().ifThrown(entityNone()))
	// 				.filter!(a => a != entityNone())
	// 				.joiner();
	// pragma(msg, ElementType!(typeof(xmlDocs)));
	// // auto dom = parseDOM(xmlDocs);

	// foreach (xml; xmlDocs)
	// {
	// 	// Проверки
	// }


	// auto output = writeXmlFromEntitis(xmlDocs, AddNewRoot.yes);

	// writeln(output);
	return 0;
}


version(unittest)
{
	static string[] xmlFiles;
	static DOMEntity!string[] xmlDocs;
	static DOMEntity!string godXml;
}

unittest
{
	import std.algorithm : canFind;

	immutable dir = ["./project-name"];
	immutable files = [
		"./project-name/common/database.xml",
		"./project-name/common/ParametersOverride.xml",
		"./project-name/subfolder/service1/cfg/cfg.xml",
		"./project-name/subfolder/service2/cfg/cfg.xml",
		"./project-name/subfolder/service2/cfg/Service2Plugin1.xml",
		"./project-name/subfolder/service2/cfg/Service2Plugin2.xml"
	];


	xmlFiles = getAllXmlFrom(dir);


	assert(xmlFiles.length == 6);
	foreach(file; files)
		assert(canFind(xmlFiles, file));
}

@safe
unittest
{
	xmlDocs = parseAll(xmlFiles);

	assert(xmlDocs.length == 6);
}

@safe
unittest
{
	godXml = makeGodXml(xmlDocs);

	{
		auto passwords = process!string.toAttrs(godXml["//@password"]);
		
		assert(passwords.length == 3);

		// All attr contain the same value
		// pragma(msg, typeof(passwords));
		auto value = passwords.front.value;
		foreach (pass; passwords)
			assert(value == pass.value);
	}

	{
		auto ports = process!string.toAttrs(godXml["//@port"]);

		assert(ports.length == 12);

		auto uniquePorts = getUniqValsFromAttrs!string(ports);
		assert(uniquePorts.length == 4);

		Set!string pp = Set!string([
			"5432", // database
			"24051", // Service2Plagin1
			"7007", // service1/cfg
			"12345" // Service2Plugin2
		]);
		assert(pp in uniquePorts); // выше проверка что всего 4 элемента => это они и есть
	}
}

