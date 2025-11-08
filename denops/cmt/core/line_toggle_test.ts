import { assertEquals } from "jsr:@std/assert@1.0.6/equals";
import { toggleLines } from "./line_toggle.ts";

type CommentInfo = Parameters<typeof toggleLines>[1][number];

const makeInfo = (mode: CommentInfo["mode"], prefix: string, suffix = ""): CommentInfo => ({
  mode,
  prefix,
  suffix,
  source: "test",
});

Deno.test("adds line comments when not present", () => {
  const result = toggleLines([
    "const x = 1;",
    "  const y = 2;",
  ], [makeInfo("line", "//"), makeInfo("line", "//")], "line");

  assertEquals(result.action, "comment");
  assertEquals(result.lines, [
    "// const x = 1;",
    "//   const y = 2;",
  ]);
});

Deno.test("removes line comments when already commented", () => {
  const result = toggleLines([
    "// const x = 1;",
    "//   const y = 2;",
  ], [makeInfo("line", "//"), makeInfo("line", "//")], "line");

  assertEquals(result.action, "uncomment");
  assertEquals(result.lines, [
    "const x = 1;",
    "  const y = 2;",
  ]);
});

Deno.test("wraps block comments with suffix alignment", () => {
  const result = toggleLines([
    "type A = { a: number };",
    "type B = { bb: string };",
  ], [
    makeInfo("block", "/*", "*/"),
    makeInfo("block", "/*", "*/"),
  ], "block");

  assertEquals(result.lines, [
    "/* type A = { a: number };  */",
    "/* type B = { bb: string }; */",
  ]);
});

Deno.test("line comments preserve visual body indent inside prefix", () => {
  const source = [
    "vi.mock(\"@/server/utils/id-generator\", () => ({",
    "  generateReplayId: vi.fn(),",
    "  generateUUID: vi.fn(),",
    "))",
  ];
  const infos = source.map(() => makeInfo("line", "//"));

  const commented = toggleLines(source, infos, "line");
  assertEquals(commented.lines, [
    "// vi.mock(\"@/server/utils/id-generator\", () => ({",
    "//   generateReplayId: vi.fn(),",
    "//   generateUUID: vi.fn(),",
    "// ))",
  ]);

  const uncommented = toggleLines(commented.lines, infos, "line");
  assertEquals(uncommented.lines, source);
});

Deno.test("falls back to block markers when only block mode is available", () => {
  const lines = [
    "<div>",
    "  <span>text</span>",
    "</div>",
  ];
  const infos = lines.map(() => makeInfo("block", "{/*", "*/}"));
  const result = toggleLines(lines, infos, "line");
  assertEquals(result.lines, [
    "{/* <div>               */}",
    "{/*   <span>text</span> */}",
    "{/* </div>              */}",
  ]);
});
