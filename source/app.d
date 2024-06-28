debug import std.logger;

import std.stdio;
import std.file;
import std.path;
import std.algorithm : map, joiner, filter, copy;

import std.array : array, Appender, appender;
import std.range : walkLength, take, ElementType;
import std.typecons : Flag, Yes, No;
import std.exception : ifThrown, enforce;
import std.meta : AliasSeq;
import std.traits : isInstanceOf;

import dxml.dom;
import dxml.parser;
import dxml.util;
import dxml.writer;

import dxml.xpath;
import set;


alias AddNewRoot = Flag!"AddNewRoot";

alias MyEntityTemplate = AliasSeq!(simpleXML, string);

DOMEntity!R entityNone (R) ()
{
	return DOMEntity!(R)();
}

DOMEntity!string entityNone () ()
{
	return entityNone!(string)();
}

string writeXmlFromEntitis (IR)(IR xmlEntities)
{
	auto writer = xmlWriter(appender!string());

	foreach (entity; xmlEntities)
	{
		final switch (entity.type())
		{
		case EntityType.comment:
			writer.writeComment(entity.text());
			break;
		case EntityType.cdata:
			writer.writeCDATA(entity.text());
			break;
		case EntityType.elementEmpty:
			writer.openStartTag(entity.name());
			foreach (attr; entity.attributes())
				writer.writeAttr(attr.name, attr.value);
			writer.closeStartTag(EmptyTag.yes);
			break;
		case EntityType.elementEnd:
			writer.writeEndTag(entity.name());
			break;
		case EntityType.elementStart:
			writer.openStartTag(entity.name());
			foreach (attr; entity.attributes())
				writer.writeAttr(attr.name, attr.value);
			writer.closeStartTag();
			break;
		case EntityType.pi:
			writer.writePI(entity.name(), entity.text());
			break;
		case EntityType.text:
			writer.writeText(entity.text().stripIndent());
			break;

		}
	}
	
	return writer.output().data();
}

/// Прямой обход дерева
string writeXmlFromDOM (IR)(IR xmlDom)
{
	auto writer = xmlWriter(appender!string());
	
	void writeNode(IR node)
	{
		// writeln(node);
		final switch (node.type())
		{
		case EntityType.comment:
			writer.writeComment(node.text());
			break;
		case EntityType.cdata:
			writer.writeCDATA(node.text());
			break;
		case EntityType.elementEmpty:
			writer.openStartTag(node.name());
			foreach (attr; node.attributes())
				writer.writeAttr(attr.name, attr.value);
			writer.closeStartTag(EmptyTag.yes);
			break;
		case EntityType.elementEnd:
			enforce("В DOM такой тип не встречается. Чтоб избежать UB - ошибка");
			break;
		case EntityType.elementStart:
			if (node.name() != "") {
				writer.openStartTag(node.name());
				foreach (attr; node.attributes())
					writer.writeAttr(attr.name, attr.value);
				writer.closeStartTag();
			}
			foreach (child; node.children())
				writeNode(child);
			if (node.name() != "") 
				writer.writeEndTag(node.name());
			break;
		case EntityType.pi:
			writer.writePI(node.name(), node.text());
			break;
		case EntityType.text:
			writer.writeText(node.text().stripIndent());
			break;
		}
	}
	
	writeNode(xmlDom);

	return writer.output().data();
}

DOMEntity!string toDomEntity (ref process!string.Expr sumType) @safe
{
	return std.sumtype.tryMatch!(
		(ref DOMEntity!string dom) => dom
	)(sumType);
}

enum FILENAME_ATTR = "filename";
/// Добавить путь к файлу как атребут корнегого элемента
void addFilePathAsAttr (R) (ref DOMEntity!R xml, R filePath) @safe
in (isValidPath(filePath))
{
	//TODO:
	/*
	* Можно сделать вызов delegate в функции обработки xpath. Чтоб менять занчения.
	* Для геттера это будет ничего не делающая f.
	*/


	std.sumtype.tryMatch!(
		(ref DOMEntity!R node) => node.attributes() ~= (DOMEntity!R).Attribute(FILENAME_ATTR, filePath, TextPos(-1, -1))
	)(xml["/*"].front); 
}


/// Чтоб обновить все позиции в дереве DOM  
/// Не рекомендуется часто вызывать
DOMEntity!S restruct (S) (DOMEntity!S node) @safe
{
	// ну типо костыль.
	// Дерево (пишется в)-> текст xml (парсится)-> дерево
	// Просто, но затратно
	return parseDOM(writeXmlFromDOM(node));
}


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

		// All attr contain the same vaue
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
		assert(pp in uniquePorts);
	}
}


Set!R getUniqValsFromAttrs (R, Attr)(Set!(Attr) attrs)
{
	typeof(return) result;
	foreach (attr; attrs)
		result ~= attr.value;
	return result;
}


R[] getAllXmlFrom (R)(in R[] paths)
{
	import std.file;
	R[] files;
	foreach (R path; paths)
	{
		if (isFile(path) && extension(path) == ".xml") files ~= path;
		if (isDir(path))
			foreach(file; dirEntries(path, SpanMode.depth))
			{
				if (isFile(file) && extension(file) == ".xml")
					files ~= file;
			}
	}
	return files;
}


DOMEntity!R[] parseAll (R)(in R[] xmlFiles) @safe
{
	DOMEntity!R[] docs;
	foreach (path; xmlFiles)
	{
		DOMEntity!R a = readText(path).parseDOM();
		if (a == entityNone())
			continue;
		// addFilePathAsAttr(a, path); // BUG: не записывает
		docs ~= restruct(a);
	}
	return docs;
}

DOMEntity!R makeGodXml (R)(DOMEntity!R[] xmlDocs) @safe
{
	DOMEntity!string god = parseDOM(`<god-xml></god-xml>`);
	foreach (xml; xmlDocs)
		god.children[0].children() ~= xml.children();
	return restruct(god);
}