import std.logger;

import std.stdio;
import std.file;
import std.algorithm : map, joiner, filter, copy;

import std.array : array, Appender, appender;
import std.range : walkLength, take, ElementType;
import std.typecons : Flag, Yes, No;
import std.exception : ifThrown, enforce;
import std.meta : AliasSeq;

import dxml.dom;
import dxml.parser;
import dxml.writer;
import std.path;

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

string writeXmlFromEntitis (IR)(IR xmlEntities, AddNewRoot addNewRoot = AddNewRoot.no)
{
	auto writer = xmlWriter(appender!string());

	if (addNewRoot)
		writer.writeStartTag("newrooooot");

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
			writer.writeText(entity.text());
			break;

		}
	}

	if (addNewRoot)
		writer.writeEndTag("newrooooot");
	
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
			writer.writeText(node.text());
			break;
		}
	}
	
	writeNode(xmlDom);

	return writer.output().data();
}


void main(string[] args)
{
	infof("Args: %s", args);
	
	string[] xmlFiles;
	foreach (string path; args[1..$])
	{
		if (isFile(path)) xmlFiles ~= path;
		if (isDir(path))
			foreach(file; dirEntries(path, SpanMode.depth))
			{
				xmlFiles ~= file;
			}
		
	}

	info(xmlFiles);

	DOMEntity!string[] xmlDocs;
	foreach (path; xmlFiles)
	{
		auto a = readText(path).parseDOM().ifThrown(entityNone());
		if (a == entityNone())
			continue;
		xmlDocs ~= a;
	}

	// writeln(xmlDocs);

	DOMEntity!string godXml;
	godXml = xmlDocs[0];
	godXml.children()[1].children()[1] = xmlDocs[1].children()[0].children()[0];

	string output = writeXmlFromDOM(godXml);
	writeln(output);



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
}
