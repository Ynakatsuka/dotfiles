-- yazi init script.
-- Plugins installed via `ya pkg add` are registered here.
-- See ~/.config/yazi/package.toml for the list of installed plugins.

-- git.yazi: show git status markers as a linemode in the file list.
-- Requires the corresponding fetcher registration in yazi.toml.
require("git"):setup {
	order = 1500,
}
