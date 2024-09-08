module bigtest;

// local
import set;
import xmlutils;
import xmldom;
import xpath;

version(unittest)
{
	static string[] xmlFiles;
	static XMLNode!string[] xmlDocs;
	static XMLNode!string godXml;
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

unittest
{
	xmlDocs = parseAll(xmlFiles);

	assert(xmlDocs.length == 6);
}

unittest
{
	godXml = makeGodXml(xmlDocs);

	{
		auto passwords = godXml["//@password"].toAttrs();
		
		assert(passwords.length == 3);

		// All attr contain the same value
		// pragma(msg, typeof(passwords));
		auto value = passwords.front.value;
		foreach (pass; passwords)
			assert(value == pass.value);
	}

	{
		auto ports = godXml["//@port"].toAttrs();

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

	{
		// mutable
		foreach (ref n; godXml["//cfg"].toNodes())
			n.name = "config";
		assert(godXml["//config"].toNodes().front.name == "config");
		foreach (ref n; godXml["//config"].toNodes())
			n.name = "cfg";
	}
}


// Issue #3
unittest
{
	immutable testFile = "test/test1/test.xml";
	auto a = parseAll([testFile]);
	assert(a.length == 1);
}

// Issue #3
unittest
{
	immutable testFile = "test/test2/test.xml";
	auto a = parseAll([testFile]);
	assert(a.length == 1);
}