module tree;

struct Node
{
	string caption;
	Node[] children;

	void renderHeader(W)(ref W writer) @trusted const
	{
		// Available space in the writer
		const avail = (writer.Size - writer.length);
		const l = (avail < caption.length) ? avail : caption.length;
		writer.put(caption[0 .. l]);
	}
}
