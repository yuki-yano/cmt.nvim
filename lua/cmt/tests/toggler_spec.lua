local toggler = require("cmt.toggler")

local function make_info(mode, prefix, suffix)
  return {
    mode = mode,
    prefix = prefix,
    suffix = suffix or "",
    source = "test",
    resolvable = true,
  }
end

describe("cmt.toggler.toggle_lines", function()
  it("adds line comments when not present", function()
    local result = toggler.toggle_lines({
      "const x = 1;",
      "  const y = 2;",
    }, {
      make_info("line", "//"),
      make_info("line", "//"),
    }, "line")

    assert.equals("comment", result.action)
    assert.are.same({
      "// const x = 1;",
      "//   const y = 2;",
    }, result.lines)
  end)

  it("removes line comments when already commented", function()
    local result = toggler.toggle_lines({
      "// const x = 1;",
      "//   const y = 2;",
    }, {
      make_info("line", "//"),
      make_info("line", "//"),
    }, "line")

    assert.equals("uncomment", result.action)
    assert.are.same({
      "const x = 1;",
      "  const y = 2;",
    }, result.lines)
  end)

  it("wraps block comments with suffix alignment", function()
    local result = toggler.toggle_lines({
      "type A = { a: number };",
      "type B = { bb: string };",
    }, {
      make_info("block", "/*", "*/"),
      make_info("block", "/*", "*/"),
    }, "block")

    assert.are.same({
      "/* type A = { a: number };  */",
      "/* type B = { bb: string }; */",
    }, result.lines)
  end)

  it("line comments preserve visual body indent inside prefix", function()
    local source = {
      'vi.mock("@/server/utils/id-generator", () => ({',
      "  generateReplayId: vi.fn(),",
      "  generateUUID: vi.fn(),",
      "))",
    }
    local infos = {
      make_info("line", "//"),
      make_info("line", "//"),
      make_info("line", "//"),
      make_info("line", "//"),
    }

    local commented = toggler.toggle_lines(source, infos, "line")
    assert.are.same({
      '// vi.mock("@/server/utils/id-generator", () => ({',
      "//   generateReplayId: vi.fn(),",
      "//   generateUUID: vi.fn(),",
      "// ))",
    }, commented.lines)

    local uncommented = toggler.toggle_lines(commented.lines, infos, "line")
    assert.are.same(source, uncommented.lines)
  end)

  it("aligns line comments to the shared indent for nested selections", function()
    local source = {
      '  method: "POST",',
      "  headers: {",
      '    "Content-Type": "application/json",',
      "    Authorization: `Bearer ${options.apiKey}`,",
      "  },",
    }
    local infos = {
      make_info("line", "//"),
      make_info("line", "//"),
      make_info("line", "//"),
      make_info("line", "//"),
      make_info("line", "//"),
    }

    local commented = toggler.toggle_lines(source, infos, "line")
    assert.are.same({
      '  // method: "POST",',
      "  // headers: {",
      '  //   "Content-Type": "application/json",',
      "  //   Authorization: `Bearer ${options.apiKey}`,",
      "  // },",
    }, commented.lines)

    local uncommented = toggler.toggle_lines(commented.lines, infos, "line")
    assert.are.same(source, uncommented.lines)
  end)

  it("aligns block comments to the shared indent for nested selections", function()
    local source = {
      '  method: "POST",',
      "  headers: {",
      '    "Content-Type": "application/json",',
      "    Authorization: `Bearer ${options.apiKey}`,",
      "  },",
    }
    local infos = {
      make_info("block", "/*", "*/"),
      make_info("block", "/*", "*/"),
      make_info("block", "/*", "*/"),
      make_info("block", "/*", "*/"),
      make_info("block", "/*", "*/"),
    }

    local commented = toggler.toggle_lines(source, infos, "block")
    assert.are.same({
      '  /* method: "POST",                              */',
      "  /* headers: {                                   */",
      '  /*   "Content-Type": "application/json",        */',
      "  /*   Authorization: `Bearer ${options.apiKey}`, */",
      "  /* },                                           */",
    }, commented.lines)

    local uncommented = toggler.toggle_lines(commented.lines, infos, "block")
    assert.are.same(source, uncommented.lines)
  end)

  it("aligns line comments even when the selection starts at column 0", function()
    local source = {
      "const ensureReplayHistory = (get: Getter, set: Setter, replayData: ReplayData): Array<HistoryEntry> => {",
      "  const currentHistory = get(gameHistoryAtom)",
      "  if (currentHistory.length === replayData.operations.length + 1) {",
      "    return currentHistory",
      "  }",
      "",
      "  const initialState = produce(replayData.startSnapshot, () => {})",
      "  const fullHistory = buildReplayHistory(initialState, replayData.operations)",
      "  set(gameHistoryAtom, fullHistory)",
      "  return fullHistory",
      "}",
    }
    local infos = {}
    for idx = 1, #source do
      infos[idx] = make_info("line", "//")
    end

    local commented = toggler.toggle_lines(source, infos, "line")
    assert.are.same({
      "// const ensureReplayHistory = (get: Getter, set: Setter, replayData: ReplayData): Array<HistoryEntry> => {",
      "//   const currentHistory = get(gameHistoryAtom)",
      "//   if (currentHistory.length === replayData.operations.length + 1) {",
      "//     return currentHistory",
      "//   }",
      "",
      "//   const initialState = produce(replayData.startSnapshot, () => {})",
      "//   const fullHistory = buildReplayHistory(initialState, replayData.operations)",
      "//   set(gameHistoryAtom, fullHistory)",
      "//   return fullHistory",
      "// }",
    }, commented.lines)

    local uncommented = toggler.toggle_lines(commented.lines, infos, "line")
    assert.are.same(source, uncommented.lines)
  end)

  it("aligns block comments even when the selection starts at column 0", function()
    local source = {
      "const ensureReplayHistory = (get: Getter, set: Setter, replayData: ReplayData): Array<HistoryEntry> => {",
      "  const currentHistory = get(gameHistoryAtom)",
      "  if (currentHistory.length === replayData.operations.length + 1) {",
      "    return currentHistory",
      "  }",
      "",
      "  const initialState = produce(replayData.startSnapshot, () => {})",
      "  const fullHistory = buildReplayHistory(initialState, replayData.operations)",
      "  set(gameHistoryAtom, fullHistory)",
      "  return fullHistory",
      "}",
    }
    local infos = {}
    for idx = 1, #source do
      infos[idx] = make_info("block", "/*", "*/")
    end

    local commented = toggler.toggle_lines(source, infos, "block")
    assert.are.same({
      "/* const ensureReplayHistory = (get: Getter, set: Setter, replayData: ReplayData): Array<HistoryEntry> => { */",
      "/*   const currentHistory = get(gameHistoryAtom)                                                            */",
      "/*   if (currentHistory.length === replayData.operations.length + 1) {                                      */",
      "/*     return currentHistory                                                                                */",
      "/*   }                                                                                                      */",
      "",
      "/*   const initialState = produce(replayData.startSnapshot, () => {})                                       */",
      "/*   const fullHistory = buildReplayHistory(initialState, replayData.operations)                            */",
      "/*   set(gameHistoryAtom, fullHistory)                                                                      */",
      "/*   return fullHistory                                                                                     */",
      "/* }                                                                                                        */",
    }, commented.lines)

    local uncommented = toggler.toggle_lines(commented.lines, infos, "block")
    assert.are.same(source, uncommented.lines)
  end)

  it("falls back to block markers when only block mode is available", function()
    local lines = {
      "<div>",
      "  <span>text</span>",
      "</div>",
    }
    local infos = {
      make_info("block", "{/*", "*/}"),
      make_info("block", "{/*", "*/}"),
      make_info("block", "{/*", "*/}"),
    }

    local result = toggler.toggle_lines(lines, infos, "line")
    assert.are.same({
      "{/* <div>               */}",
      "{/*   <span>text</span> */}",
      "{/* </div>              */}",
    }, result.lines)
  end)

  it("obeys mixed mode policies", function()
    local lines = {
      "<div>",
      "  className",
    }
    local infos = {
      make_info("block", "{/*", "*/}"),
      make_info("line", "//"),
    }

    local mixed = toggler.toggle_lines(lines, infos, "line", "mixed")
    assert.are.same({
      "{/* <div> */}",
      "  // className",
    }, mixed.lines)

    local block_policy = toggler.toggle_lines(lines, infos, "line", "block")
    assert.are.same({
      "{/* <div>       */}",
      "{/*   className */}",
    }, block_policy.lines)

    local line_policy = toggler.toggle_lines(lines, infos, "line", "line")
    assert.are.same({
      "// <div>",
      "//   className",
    }, line_policy.lines)
  end)

  it("preserves blank lines when toggling", function()
    local lines = {
      "",
      "value",
    }
    local infos = {
      make_info("line", "//"),
      make_info("line", "//"),
    }
    local commented = toggler.toggle_lines(lines, infos, "line")
    assert.are.same({
      "",
      "// value",
    }, commented.lines)
    local uncommented = toggler.toggle_lines(commented.lines, infos, "line")
    assert.are.same(lines, uncommented.lines)
  end)

  it("uses preferred mode when first-line policy lacks info", function()
    local lines = {
      "foo()",
      "bar()",
    }
    local infos = {
      false,
      make_info("block", "/*", "*/"),
    }
    local result = toggler.toggle_lines(lines, infos, "block", "first-line")
    assert.are.same({
      "/* foo() */",
      "/* bar() */",
    }, result.lines)
  end)
end)
