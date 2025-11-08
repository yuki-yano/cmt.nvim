export type ToggleMode = "line" | "block";

export type CommentInfo = {
  mode: ToggleMode;
  prefix: string;
  suffix: string;
  source?: string;
  resolvable?: boolean;
};

export type ToggleResult = {
  lines: string[];
  action: "comment" | "uncomment";
};

const displayWidth = (value: string): number => {
  const graphemes = Array.from(value.normalize());
  return graphemes.reduce((sum, ch) => sum + (ch.charCodeAt(0) > 0xff ? 2 : 1), 0);
};

const stripIndent = (line: string) => {
  const match = line.match(/^\s*/);
  const indent = match ? match[0] : "";
  return { indent, body: line.slice(indent.length) };
};

const longestCommonIndent = (indents: string[]): string => {
  if (indents.length === 0) {
    return "";
  }
  let prefix = indents[0];
  for (let idx = 1; idx < indents.length && prefix.length > 0; idx++) {
    const target = indents[idx];
    let commonLength = 0;
    const max = Math.min(prefix.length, target.length);
    while (commonLength < max && prefix[commonLength] === target[commonLength]) {
      commonLength++;
    }
    prefix = prefix.slice(0, commonLength);
  }
  return prefix;
};

const isLineCommented = (line: string, info: CommentInfo) => {
  const { indent, body } = stripIndent(line);
  const target = body.trimStart();
  if (target.length === 0) {
    return false;
  }
  const prefix = info.prefix.trimEnd();
  return target.startsWith(prefix);
};

const removeLineComment = (line: string, info: CommentInfo) => {
  const { indent, body } = stripIndent(line);
  const trimmedPrefix = info.prefix.trimEnd();
  if (!body.trimStart().startsWith(trimmedPrefix)) {
    return line;
  }
  const start = body.indexOf(trimmedPrefix);
  let rest = body.slice(start + trimmedPrefix.length);
  if (rest.startsWith(" ")) {
    rest = rest.slice(1);
  }
  return indent + rest;
};

const alignLineComments = (lines: string[], infos: CommentInfo[]) => {
  const entries = lines.map((line) => stripIndent(line));
  const sharedIndent = longestCommonIndent(entries.map((entry) => entry.indent));
  return entries.map((entry, idx) => {
    const info = infos[idx] ?? infos[0];
    const rest = entry.indent.slice(sharedIndent.length) + entry.body;
    const pad = rest.length > 0 ? " " : "";
    return `${sharedIndent}${info.prefix}${pad}${rest}`;
  });
};

const isBlockCommented = (line: string, info: CommentInfo) => {
  const trimmed = line.trim();
  return trimmed.startsWith(info.prefix) && trimmed.endsWith(info.suffix);
};

const removeBlockComment = (line: string, info: CommentInfo) => {
  const trimmed = line.trim();
  if (!trimmed.startsWith(info.prefix) || !trimmed.endsWith(info.suffix)) {
    return line;
  }
  let inner = trimmed.slice(info.prefix.length);
  inner = inner.slice(0, inner.length - info.suffix.length).trim();
  const indent = line.match(/^\s*/)?.[0] ?? "";
  return indent + inner;
};

const addBlockComments = (lines: string[], infos: CommentInfo[]) => {
  const stripped = lines.map((line) => stripIndent(line));
  const sharedIndent = longestCommonIndent(stripped.map((entry) => entry.indent));
  const bodies = stripped.map((entry) => entry.indent.slice(sharedIndent.length) + entry.body);
  const widths = bodies.map((body) => displayWidth(body));
  const maxWidth = Math.max(...widths, 0);
  return bodies.map((body, idx) => {
    const info = infos[idx];
    const prefixPad = body.length > 0 ? " " : "";
    const width = widths[idx];
    const suffixPadLength = Math.max(maxWidth - width + 1, 1);
    const suffixPad = " ".repeat(suffixPadLength);
    return `${sharedIndent}${info.prefix}${prefixPad}${body}${suffixPad}${info.suffix}`;
  });
};

export const toggleLines = (
  lines: string[],
  infos: CommentInfo[],
  preferred: ToggleMode,
): ToggleResult => {
  if (lines.length === 0) {
    return { lines, action: "comment" };
  }

  const anyBlock = infos.some((info) => info.mode === "block");
  const useMode = preferred === "block" || anyBlock ? "block" : "line";

  if (useMode === "line") {
    const already = lines.every((line, idx) => isLineCommented(line, infos[idx] ?? infos[0]));
    const updated = already
      ? lines.map((line, idx) => removeLineComment(line, infos[idx] ?? infos[0]))
      : alignLineComments(lines, infos);
    return { lines: updated, action: already ? "uncomment" : "comment" };
  }

  const alreadyBlock = lines.every((line, idx) => isBlockCommented(line, infos[idx] ?? infos[0]));
  const updated = alreadyBlock
    ? lines.map((line, idx) => removeBlockComment(line, infos[idx] ?? infos[0]))
    : addBlockComments(lines, infos);
  return { lines: updated, action: alreadyBlock ? "uncomment" : "comment" };
};
