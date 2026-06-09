# Hệ thống tri thức PTĐHR (PDE exam knowledge system)

Hệ thống hoá môn Phương trình Đạo hàm riêng để thi (được mang tài liệu).

## Dùng thế nào

Trong chat Claude Code, gửi đề một dạng bài kèm marker `#capture`:

```
#capture Giải phương trình truyền nhiệt u_t = a^2 u_xx trên (0,L), u(0,t)=u(L,t)=0, u(x,0)=f(x).
```

Hook `UserPromptSubmit` nhận diện `#capture` → chèn playbook → orchestrator chạy:

```
3 explorer (Opus, song song)  →  synthesizer (Opus)  →  3 writer (Sonnet, song song)
  by-concept                       gộp + khử trùng lặp     kg-writer    → knowledge/*.md
  by-method                        → analysis.json         latex-writer → exam/**
  by-equation-type                                         html-writer  → feedback/*.html
```

**Lần đầu KHÔNG giải bài** — chỉ khai phá: khái niệm, dạng bài lân cận, phương pháp +
điều kiện áp dụng, định nghĩa lý thuyết.

## Ba tầng

| Tầng | Thư mục | Vai trò |
|------|---------|---------|
| Tri thức (md) | `knowledge/` | Nguồn sự thật lý thuyết + graph. File khái niệm tồn tại = "đã biết". |
| Tài liệu thi (LaTeX) | `exam/` | Mang vào phòng thi. Mỗi dạng bài 1 subfolder, `\input` fragment chung (DRY). |
| Feedback (HTML) | `feedback/` | Xem + thảo luận với AI, công thức render bằng KaTeX. |

Scratch mỗi lần chạy: `.capture/<slug>/`.

## Agents

`.claude/agents/`: pde-explorer-by-concept, -by-method, -by-equation-type, pde-synthesizer,
pde-kg-writer, pde-latex-writer, pde-html-writer.

## Toolchain

- HTML: KaTeX qua CDN (không cần cài).
- PDF thi: `tectonic` (1 binary) hoặc MiKTeX + latexmk biên dịch `exam/main.tex`.

## Thiết kế

`docs/superpowers/specs/2026-06-06-pde-exam-system-design.md`.
