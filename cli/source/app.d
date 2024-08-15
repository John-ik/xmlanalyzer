module app;

import std.logger;
import std.stdio;

import xmldom;
import xmlutils;
import xpath_grammar;

int main (string[] args)
{
	auto godXml = args[1..$].getAllXmlFrom().parseAll().makeGodXml();


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