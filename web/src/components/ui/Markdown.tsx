import { Fragment, type ReactNode } from "react";

/**
 * Minimal, dependency-free markdown renderer for AI responses.
 * Handles headings, bullet/numbered lists, bold, inline code, and paragraphs.
 * Builds React nodes directly (no dangerouslySetInnerHTML) so it is XSS-safe.
 */

function renderInline(text: string, keyBase: string): ReactNode[] {
  const nodes: ReactNode[] = [];
  // Split on **bold** and `code`, keeping delimiters.
  const tokens = text.split(/(\*\*[^*]+\*\*|`[^`]+`)/g);
  tokens.forEach((tok, i) => {
    if (!tok) return;
    if (tok.startsWith("**") && tok.endsWith("**")) {
      nodes.push(
        <strong key={`${keyBase}-b-${i}`} className="font-semibold text-[var(--text-primary)]">
          {tok.slice(2, -2)}
        </strong>
      );
    } else if (tok.startsWith("`") && tok.endsWith("`")) {
      nodes.push(
        <code key={`${keyBase}-c-${i}`} className="font-mono text-[0.85em]">
          {tok.slice(1, -1)}
        </code>
      );
    } else {
      nodes.push(<Fragment key={`${keyBase}-t-${i}`}>{tok}</Fragment>);
    }
  });
  return nodes;
}

export function Markdown({ content }: { content: string }) {
  const lines = content.replace(/\r\n/g, "\n").split("\n");
  const blocks: ReactNode[] = [];
  let list: { ordered: boolean; items: string[] } | null = null;

  const flushList = (key: string) => {
    if (!list) return;
    const Tag = list.ordered ? "ol" : "ul";
    blocks.push(
      <Tag
        key={key}
        className={`my-2 space-y-1 pl-5 ${list.ordered ? "list-decimal" : "list-disc"}`}
      >
        {list.items.map((it, i) => (
          <li key={i} className="text-[var(--text-secondary)] leading-relaxed marker:text-[var(--text-tertiary)]">
            {renderInline(it, `${key}-li-${i}`)}
          </li>
        ))}
      </Tag>
    );
    list = null;
  };

  lines.forEach((raw, idx) => {
    const line = raw.trimEnd();
    const key = `blk-${idx}`;

    const heading = line.match(/^(#{1,3})\s+(.*)$/);
    const bullet = line.match(/^[-*•]\s+(.*)$/);
    const numbered = line.match(/^\d+[.)]\s+(.*)$/);

    if (bullet) {
      if (!list || list.ordered) flushList(`${key}-pre`);
      list = list && !list.ordered ? list : { ordered: false, items: [] };
      list.items.push(bullet[1]);
      return;
    }
    if (numbered) {
      if (!list || !list.ordered) flushList(`${key}-pre`);
      list = list && list.ordered ? list : { ordered: true, items: [] };
      list.items.push(numbered[1]);
      return;
    }

    flushList(`${key}-flush`);

    if (heading) {
      const level = heading[1].length;
      const cls =
        level === 1
          ? "text-base font-semibold mt-3 mb-1"
          : "text-sm font-semibold mt-3 mb-1";
      blocks.push(
        <p key={key} className={`text-[var(--text-primary)] ${cls}`}>
          {renderInline(heading[2], key)}
        </p>
      );
      return;
    }

    if (line.trim() === "") return;

    blocks.push(
      <p key={key} className="my-1.5 leading-relaxed text-[var(--text-secondary)]">
        {renderInline(line, key)}
      </p>
    );
  });

  flushList("blk-final");

  return <div className="text-sm">{blocks}</div>;
}
