import std.logger;

import std.stdio;
import std.file;
import std.algorithm : map, joiner, filter;

import std.array : array, Appender, appender;
import std.range : walkLength;
import std.typecons : Flag, Yes, No;
import std.exception : ifThrown;

import dxml.parser;
import dxml.writer;

alias AddNewRoot = Flag!"AddNewRoot";

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
			writer.writeStartTag(entity.name(), EmptyTag.yes);
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


void main(string[] args)
{
	infof("Args: %s", args);
	
	string[] xmlFiles;
	foreach (string path; args)
	{
		if (isFile(path)) xmlFiles ~= path;
		if (isDir(path))
			foreach(file; dirEntries(path, SpanMode.depth))
			{
				xmlFiles ~= file;
			}
		
	}


	auto xmlDocs = map!(a => readText(a).parseXML!simpleXML().ifThrown(EntityRange!(simpleXML, string)()))(xmlFiles[1..$])
					.filter!(a => a != EntityRange!(simpleXML, string)())
					.joiner();
	

	auto output = writeXmlFromEntitis(xmlDocs, AddNewRoot.yes);

	writeln(output);
}
