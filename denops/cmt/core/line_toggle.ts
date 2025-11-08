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
  const primaryLine = infos.find((info) => info.mode === "line") ?? infos[0];
  return entries.map((entry, idx) => {
    const info = infos[idx]?.mode === "line" ? infos[idx] : primaryLine;
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
    const content = `${sharedIndent}${info.prefix}${prefixPad}${body}${suffixPad}${info.suffix}`;
    return content.replace(/\s+$/, "");
  });
};

const segmentModes = (infos: CommentInfo[]): ToggleMode[] =>
  infos.map((info) => info.mode === "block" ? "block" : "line");

const runLineMode = (lines: string[], infos: CommentInfo[]) => {
  const already = lines.every((line, idx) => isLineCommented(line, infos[idx] ?? infos[0]));
  const updated = already
    ? lines.map((line, idx) => removeLineComment(line, infos[idx] ?? infos[0]))
    : alignLineComments(lines, infos);
  return { lines: updated, already };
};

const runBlockMode = (lines: string[], infos: CommentInfo[]) => {
  const primary = infos.find((info) => info.mode === "block") ?? infos[0];
  const blockInfos = infos.map((info) => info.mode === "block" ? info : primary);
  const already = lines.every((line, idx) => isBlockCommented(line, blockInfos[idx] ?? primary));
  const updated = already
    ? lines.map((line, idx) => removeBlockComment(line, blockInfos[idx] ?? primary))
    : addBlockComments(lines, blockInfos);
  return { lines: updated, already };
};

const runUniformMode = (mode: ToggleMode, lines: string[], infos: CommentInfo[]) =>
  mode === "block" ? runBlockMode(lines, infos) : runLineMode(lines, infos);

const runMixedMode = (lines: string[], infos: CommentInfo[]) => {
  const modes = segmentModes(infos);
  const segments: { start: number; end: number; mode: ToggleMode }[] = [];
  let start = 0;
  let current = modes[0] ?? "line";
  for (let idx = 1; idx < modes.length; idx++) {
    const mode = modes[idx] ?? "line";
    if (mode !== current) {
      segments.push({ start, end: idx, mode: current });
      start = idx;
      current = mode;
    }
  }
  segments.push({ start, end: modes.length, mode: current });

  const output: string[] = [...lines];
  let allAlready = true;
  for (const segment of segments) {
    const sliceLines = lines.slice(segment.start, segment.end);
    const sliceInfos = infos.slice(segment.start, segment.end);
    const result = runUniformMode(segment.mode, sliceLines, sliceInfos);
    for (let offset = 0; offset < result.lines.length; offset++) {
      output[segment.start + offset] = result.lines[offset];
    }
    allAlready = allAlready && result.already;
  }

  return { lines: output, already: allAlready };
};

export const toggleLines = (
  lines: string[],
  infos: CommentInfo[],
  preferred: ToggleMode,
  mixedPolicy: 'line' | 'block' | 'mixed' = 'mixed',
): ToggleResult => {
  if (lines.length === 0) {
    return { lines, action: "comment" };
  }

  if (mixedPolicy === 'mixed') {
    const result = runMixedMode(lines, infos);
    return { lines: result.lines, action: result.already ? "uncomment" : "comment" };
  }

  const targetMode: ToggleMode = mixedPolicy === 'block' ? 'block' : 'line';
  const result = runUniformMode(targetMode, lines, infos);
  return { lines: result.lines, action: result.already ? "uncomment" : "comment" };
};
