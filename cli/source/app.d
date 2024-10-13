module app;

import std.logger;

import std.exception;
import std.stdio;

static import options;

import xmldom;
import xmlutils;
import xpath_grammar;
import bigtest;

int main (string[] args)
{
	options.begin(args, a => a[1..$].getAllXmlFrom());

	// auto godXml = args[1..$].getAllXmlFrom().parseAll().makeGodXml();
	XMLNode!string godXml;
	if (options.god)
		godXml = options.paths.parseAll().makeGodXml();
	else if (options.paths.length == 1)
		godXml = options.paths.parseAll()[0];
	else
		enforce(false, "Without god options. Allow only one xml file");


	if (options.xpath)
	{
		writeln(godXml[options.xpath]);
	}

	if (!options.iteractive)
		return 0;

	string output = writeXmlFromDOM(godXml);
	writeln(godXml);
	writeln(output);

	// assert(godXml["//cfg/@filename"] == godXml["/././*/..//cfg/@filename"]);
	string line;
	write("Enter XPath: ");
	while ((line = stdin.readln()) !is null) {
		writefln("%(>- %s\n%)", godXml[line]);
		writeln(parseXPath(line));
		write("Enter XPath: ");
	}

    return 0;
}