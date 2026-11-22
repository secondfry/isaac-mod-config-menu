"""Syntax-checks every Lua file, then runs each test of tests/test_*.lua in a fresh Lua 5.3 state.

Run from the workspace root: .venv\\Scripts\\python -B -I config-menu\\tests\\run_tests.py
"""
import pathlib
import sys

import lupa.lua53 as lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth")


def lua_path(path):
    return path.as_posix() + ("/" if path.is_dir() else "")


def new_runtime():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ROOT = lua_path(ROOT)
    g.GAME_SCRIPTS = lua_path(GAME / "resources" / "scripts")
    g.GAME_MODS = lua_path(GAME / "mods")
    lua.execute('dofile(ROOT .. "tests/stub.lua") dofile(ROOT .. "tests/check.lua")')
    return lua


def syntax_errors():
    lua = lupa.LuaRuntime()
    check = lua.eval("function(path) local f, err = loadfile(path) return err end")
    errors = []
    for path in sorted(ROOT.rglob("*.lua")):
        err = check(lua_path(path))
        if err:
            errors.append(err)
    return errors, len(list(ROOT.rglob("*.lua")))


def test_names(test_file):
    lua = new_runtime()
    tests = lua.execute(f'return dofile("{lua_path(test_file)}")')
    return [tests[i][1] for i in range(1, len(tests) + 1)]


def run_one(test_file, index):
    lua = new_runtime()
    runner = lua.eval(
        "function(file, i) local tests = dofile(file) local ok, err = pcall(tests[i][2]) return ok, tostring(err) end"
    )
    return runner(lua_path(test_file), index)


def main():
    errors, count = syntax_errors()
    for err in errors:
        print("SYNTAX", err)
    print(f"syntax: {count - len(errors)}/{count} Lua files load")
    passed = failed = 0
    for test_file in sorted((ROOT / "tests").glob("test_*.lua")):
        for i, name in enumerate(test_names(test_file), start=1):
            success, message = run_one(test_file, i)
            if success:
                passed += 1
            else:
                failed += 1
                print(f"FAIL {test_file.name} :: {name}\n    {message}")
    print(f"tests: {passed} passed, {failed} failed")
    sys.exit(1 if failed or errors else 0)


if __name__ == "__main__":
    main()
