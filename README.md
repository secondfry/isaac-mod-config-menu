# Config Menu

A Binding of Isaac: Repentance+ mod (vanilla Lua, no REPENTOGON) that provides the Mod Config Menu API other mods build their settings pages with. Written from a behaviour spec, not from the original's code.

**Do not run it alongside Mod Config Menu Impure or Mod Config Menu Pure.** Enable only one of the three.

## Using it in game

Press **L** (keyboard) or click the **right stick** (gamepad) in a cleared room to open the menu; the keys can be changed on its own "Config Menu" page. Arrows, WASD or either stick move; Enter, Space or E select; Esc, Q, Tab or Backspace go back; R on a setting restores its default.

## Compatibility

The metadata name starts with a space so the game loads it before the mods that look for the menu at their own load.

- Globals `MCM` and `ModConfigMenu` hold one API table; `ScreenHelper`, `InputHelper` and `FilepathHelper` point at the same table, and `require("scripts.modconfig")` returns it. `ModConfigMenuData` is `MenuData`. Deprecated `ModConfigMenuController`, `ModConfigMenuKeyboardToString`, `ModConfigMenuControllerToString`, `ModConfigMenuPopupGfx` and `ModConfigMenuOptionType` still forward, with a notice. `Controller` is created when absent.
- As `FilepathHelper` it replaces `Isaac.RegisterMod` (the engine's stays as `OldRegisterMod`) so every mod registered after it gets a string `path` with its root folder, which Encyclopedia relies on; `Version` keeps Encyclopedia's own copy from installing.
- While the menu is open, Esc and the pause button act as Back: the game's pause checks read false.
- `OptionType` (TEXT 1, SPACE 2, SCROLL 3, BOOLEAN 4, NUMBER 5, KEYBIND_KEYBOARD 6, KEYBIND_CONTROLLER 7, TITLE 8) and `PopupGfx` (THIN/WIDE x SMALL/MEDIUM/LARGE).
- Data: `GetCategoryIDByName`, `UpdateCategory`, `SetCategoryInfo`, `RemoveCategory`, `GetSubcategoryIDByName`, `UpdateSubcategory`, `RemoveSubcategory`, `AddSetting`, `AddText`, `AddTitle`, `AddSpace`, `RemoveSetting`; `MenuData` may also be written directly.
- Helper settings stored in `Config` and saved by the menu: `AddBooleanSetting`, `AddNumberSetting`, `AddScrollSetting`, `AddKeyboardSetting`, `AddControllerSetting`, with the original's optional-argument shifting.
- Setting fields: Type, CurrentSetting, Display, OnChange, Info, Minimum, Maximum, ModifyBy, NoLoopFromMaxMin, Default, Popup, PopupGfx, PopupWidth, OnSelect, Restart, Rerun, NoUnbind, Color, NoCursorHere, ShowStrikeout, HideControls, ShowOffset, Sound, AltSlider, Attribute. Each visible row's Display runs once per frame while the menu is open.
- Menu state and helpers: `IsVisible`, `OpenConfigMenu`, `CloseConfigMenu`, `ToggleConfigMenu`, `RoomIsSafe`, `IgnoreActiveEnemies`, `GetCurrentFocus`, `UpdateCurrentVars`, `Config`, `ConfigDefault`, `GetSave`, `LoadSave`, `KeyboardToString`, `ControllerToString`, keyboard/action/button input helpers, `ForceActionTriggered`/`ForceActionPressed`, screen helpers with `GetOffset`/`SetOffset`, `Round`, `RoundVector`, `CopyTable`, `FillTable`, `ConvertDisplayToTextTable`, `GetMenuAnm2Sprite`, `DrawFont`, `GetIsPaused`, `Version`, `GetVersionString`, `DLC`, `WarningOffset`, `WarningOffsetDSS`.
- `Config["Mod Config Menu"]` keeps the original's keys (OpenMenuKeyboard, OpenMenuController, HideHudInMenu, ResetToDefault, ShowControls); `Config.General` mirrors the game's HUD options.
- Not built: the original's custom-callback system (`AddCustomCallback`, SaveHelper, `MCM_POST_MODIFY_SETTING`) and translation functions; no installed mod uses them.

Settings are saved per save slot in `data/config menu/saveN.dat`; nothing is migrated from the original's data folder.

## Tests

From the workspace root, with `lupa` installed: `.venv\Scripts\python -B -I config-menu\tests\run_tests.py`. They stub the Isaac API, load `json.lua` and `enums.lua` from the game folder, and load EID's, MinimapAPI's and Completion Marks' menu code from the installed mods.

## License

MIT, see `LICENSE`. All art is original.
