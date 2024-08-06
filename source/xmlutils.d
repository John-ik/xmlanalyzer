module xmlutils;

// std
import std.array : array, Appender, appender;
import std.exception : enforce;
import std.typecons : Flag, Yes, No;

// local
import set;
import xmldom;

// dxml
import dxml.parser : EntityType;
import dxml.writer;
import dxml.util : stripIndent;


/// EntityRange to string
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
/// DOMEntity to string
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


import std.path : isValidPath;


enum FILENAME_ATTR = "filename";
/// Добавить путь к файлу как атребут корнегого элемента
void addFilePathAsAttr (R) (ref XMLNode!R xml, R filePath) @safe
in (isValidPath(filePath))
{
	//  Вернул старое рабочее
	xml.children()[0].attributes() ~= (XMLNode!R).Attribute(FILENAME_ATTR, filePath, TextPos2(-1, -1));
	return; 

	//TODO:
	/*
	* Можно сделать вызов delegate в функции обработки xpath. Чтоб менять занчения.
	* Для геттера это будет ничего не делающая f.
	*/


	
}


/// Чтоб обновить все позиции в дереве DOM  
/// Не рекомендуется часто вызывать
XMLNode!S restruct (S) (XMLNode!S node) @safe
{
	// ну типо костыль.
	// Дерево (пишется в)-> текст xml (парсится)-> дерево
	// Просто, но затратно
	return parseDOM(writeXmlFromDOM(node));
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
    import std.path;
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


R preProcessComments (R) (R xmlText)
{
	import std.regex;
	auto re = regex(`(?<=(<!--[^(--)]*))(--)(?=([^(--)]*-->))`, "g");
	return replaceAll(xmlText, re, "-_-");
}

unittest
{
	immutable comment = `<!-- This is a comment -- Oops -->`;
	immutable fixed   = `<!-- This is a comment -_- Oops -->`;
	assert(preProcessComments(comment) == fixed);
}

XMLNode!R[] parseAll (R)(in R[] xmlFiles, Flag!"preProcessComment" preProcessComment = No.preProcessComment) @safe
{
	import std.file;
	XMLNode!R[] docs;
	foreach (path; xmlFiles)
	{
		auto xmlText = readText(path);
		if (preProcessComment) xmlText = preProcessComments(xmlText);
		XMLNode!R a = parseDOM(xmlText);
		if (a.empty)
			continue;
		addFilePathAsAttr(a, path); 
		docs ~= restruct(a);
	}
	return docs;
}

XMLNode!R makeGodXml (R)(XMLNode!R[] xmlDocs) @safe
{
	XMLNode!string god = parseDOM(`<god-xml></god-xml>`);
	foreach (xml; xmlDocs)
		god.children[0].children() ~= xml.children();
	return restruct(god);
}