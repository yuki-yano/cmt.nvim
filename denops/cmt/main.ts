import type { Denops } from "./deps/denops_std.ts";
import { fn } from "./deps/denops_std.ts";
import { toggleLines } from "./core/line_toggle.ts";
import type { CommentInfo } from "./core/line_toggle.ts";

const enumerate = (start: number, finish: number): number[] => {
  const values: number[] = [];
  for (let line = start; line <= finish; line++) {
    values.push(line);
  }
  return values;
};

const firstColumn = (text: string): number => {
  const match = text.match(/\S/);
  if (!match || match.index === undefined) {
    return 0;
  }
  return match.index;
};

const fetchCommentInfos = async (
  denops: Denops,
  bufnr: number,
  startLine: number,
  endLine: number,
  lines: string[],
  preferredKind: 'line' | 'block',
): Promise<CommentInfo[]> => {
  const locations = enumerate(startLine, endLine).map((line, idx) => ({
    line,
    column: firstColumn(lines[idx] ?? ""),
  }));
  const luaScript = "require('cmt.commentstring').batch_get(_A.bufnr, _A.locations, _A.kind)";
  const result = await denops.call(
    'luaeval',
    luaScript,
    { bufnr, locations, kind: preferredKind },
  ) as CommentInfo[];
  return result;
};

const needsFallback = (infos: CommentInfo[]) =>
  infos.some((info) => info.resolvable === false);

const fallbackReason = (infos: CommentInfo[]): string | undefined =>
  infos.find((info) => info.resolvable === false)?.source;

const toggleRange = async (
  denops: Denops,
  preferredKind: 'line' | 'block',
  range: { start_line: number; end_line: number },
  mixedPolicy: 'line' | 'block' | 'mixed',
): Promise<{ status: string; payload?: Record<string, unknown> }> => {
  const start = Math.max(range.start_line, 1);
  const finish = Math.max(range.end_line, start);
  const bufnr = await fn.bufnr(denops, '%');
  const lines = await fn.getline(denops, start, finish) as string[];
  if (lines.length === 0) {
    return { status: 'ok' };
  }
  const infos = await fetchCommentInfos(denops, bufnr, start, finish, lines, preferredKind);
  if (needsFallback(infos)) {
    return { status: 'fallback', payload: { mode: 'line', reason: fallbackReason(infos) } };
  }
  const result = toggleLines(lines, infos, preferredKind, mixedPolicy);
  await denops.call('nvim_buf_set_lines', bufnr, start - 1, finish, false, result.lines);
  return { status: 'ok', payload: { action: result.action } };
};

const openCommentLine = async (
  denops: Denops,
  direction: 'above' | 'below',
): Promise<{ status: string; payload?: Record<string, unknown> }> => {
  const line = await fn.line(denops, '.');
  const bufnr = await fn.bufnr(denops, '%');
  const text = await fn.getline(denops, line) as string;
  const [info] = await fetchCommentInfos(denops, bufnr, line, line, [text], 'line');
  if (!info || !info.resolvable) {
    return { status: 'fallback', payload: { mode: 'line', reason: info?.source } };
  }
  const padSpace = await denops.call(
    'luaeval',
    "vim.g.cmt_eol_insert_pad_space ~= false",
  ) as boolean;
  const pad = padSpace && info.mode === 'line' ? ' ' : '';
  const leader = info.prefix + pad;
  const opener = direction === 'below' ? 'o' : 'O';
  await denops.call('nvim_feedkeys', opener + leader, 'n', true);
  return { status: 'ok' };
};

export const main = async (denops: Denops): Promise<void> => {
  denops.dispatcher = {
    toggle: async (payload): Promise<unknown> => {
      const target = payload as {
        preferred_kind: 'line' | 'block';
        mode_policy?: 'line' | 'block' | 'mixed';
        range: { start_line: number; end_line: number };
      };
      const policy = target.mode_policy === 'line' || target.mode_policy === 'block'
        ? target.mode_policy
        : 'mixed';
      return await toggleRange(denops, target.preferred_kind, target.range, policy);
    },
    openComment: async (payload): Promise<unknown> => {
      const target = payload as { direction: 'above' | 'below' };
      return await openCommentLine(denops, target.direction);
    },
    info: async (): Promise<unknown> => {
      const bufnr = await fn.bufnr(denops, '%');
      const ft = await fn.getbufvar(denops, bufnr, '&filetype') as string;
      const line = await fn.line(denops, '.');
      const text = await fn.getline(denops, line) as string;
      const [info] = await fetchCommentInfos(denops, bufnr, line, line, [text], 'line');
      const current = info && info.resolvable ? `${info.mode}:${info.prefix}${info.suffix}` : 'unresolved';
      const source = info?.source ?? 'none';
      return {
        status: 'ok',
        payload: { message: `cmt.nvim ft=${ft} comment=${current} source=${source}` },
      };
    },
  };
};
