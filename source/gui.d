module gui;

import arsd.nanovega;
import nanogui.sdlbackend : SdlBackend;
import nanogui.widget : Widget;

class MyGui(Data) : SdlBackend
{
    Data data;

	this(int w, int h, string title, int scale)
	{
		super(w, h, title, scale);
	}

	override void onVisibleForTheFirstTime()
	{
		import nanogui.screen : Screen;
		import nanogui.widget, nanogui.theme, 
			nanogui.common, nanogui.window, nanogui.layout,
			nanogui.vscrollpanel;

		{
			const marginx = 10, marginy = 10;
			const width  = screen.width - 2*marginx;
			const height = screen.height - 2*marginy;

			auto window = new Window(screen, "XML Configurator", true);
			window.position(Vector2i(marginx, marginy));
			window.size(Vector2i(width, height));
			window.setId = "window";
			auto layout = new BoxLayout(Orientation.Vertical);
			window.layout(layout);
			layout.margin = 5;
			layout.setAlignment = Alignment.Fill;

			import nanogui.experimental.list;
			auto list = new List!(typeof(data))(window, data);
			list.collapsed = false;
			list.setId = "virtual list";
		}
		// now we should do layout manually yet
		screen.performLayout(ctx);
	}
}
