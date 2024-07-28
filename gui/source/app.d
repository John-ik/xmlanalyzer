module app;

import std.getopt : defaultGetoptPrinter, getopt;

import gui;
import tree;
import xmlutils;
import dxml.dom : DOMEntity;

Node walker(ref DOMEntity!string entity)
{
	import std.range : dropOne;
	import dxml.dom;
	
	auto node = Node();
	{
		final switch (entity.type())
		{
		case EntityType.comment:
			node.caption = entity.text;
			break;
		case EntityType.cdata:
			node.caption = entity.text;
			break;
		case EntityType.elementEmpty:
			if (entity.attributes.length)
			{
				auto a = entity.attributes()[0];
				node.caption = a.name ~ "=" ~ a.value;
				foreach (attr; entity.attributes().dropOne)
					node.caption ~= ", " ~ attr.name ~ "=" ~ attr.value;
			}
			break;
		case EntityType.elementEnd:
			node.caption = entity.text;
			break;
		case EntityType.elementStart:
			if (entity.attributes.length)
			{
				auto a = entity.attributes()[0];
				node.caption = a.name ~ "=" ~ a.value;
				foreach (attr; entity.attributes().dropOne)
					node.caption ~= ", " ~ attr.name ~ "=" ~ attr.value;
			}
			else
				node.caption = entity.name;
			foreach (child; entity.children())
				node.children ~= walker(child);
			break;
		case EntityType.pi:
			node.caption = entity.text;
			break;
		case EntityType.text:
			import dxml.util;
			node.caption = entity.text.stripIndent;
			break;
		}
	}

	if (!node.caption.length)
	{
		import std.conv : text;
		node.caption = text(entity.type);
	}
	
	return node;
}

int main (string[] args)
{
	int scale = 1;

	auto helpInformation = getopt(
		args,
		"scale", "Scale, 2 for 4K monitors and 1 for the rest", &scale,
	);

	if (helpInformation.helpWanted)
	{
		defaultGetoptPrinter("Usage:", helpInformation.options);
		return 0;
	}

	if (scale != 1 && scale != 2)
	{
		import std;
		stderr.writeln("Scale can be 1 or 2 only");
		return 1;
	}

	string[] xmlFiles = getAllXmlFrom(args[1..$]);

	auto xmlDocs = parseAll(xmlFiles);

	auto godXml = makeGodXml(xmlDocs);

	auto tree = walker(godXml.children[0]).children;

	alias Tree = typeof(tree);

	auto gui = new MyGui!Tree(1000, 800, "XML Configurator", scale);
	gui.onBeforeLoopStart = () {};
	gui.data = tree;
	gui.run();

	return 0;
}
