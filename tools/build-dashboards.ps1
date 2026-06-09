# Generate structure dashboards:
#   knowledge/index.html  — live view of the knowledge graph (concepts/problem-types/methods)
#   feedback/index.html   — live index of feedback pages + capture runs
# Scans the real folders each run. Safe on empty trees (shows empty state + structure guide).
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

function HtmlEnc([string]$s){ if($null -eq $s){return ''}; $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' }

# Pull "# Title" and frontmatter id from a md file
function Get-MdMeta([string]$path){
  $id = [IO.Path]::GetFileNameWithoutExtension($path)
  $title = $id
  foreach($l in (Get-Content $path -Encoding utf8 -TotalCount 40)){
    if($l -match '^\#\s+(.+)$'){ $title = $Matches[1].Trim(); break }
  }
  [pscustomobject]@{ id=$id; title=$title }
}

function Section-Md([string]$dir,[string]$label){
  $files = Get-ChildItem $dir -Filter *.md -File -ErrorAction SilentlyContinue | Sort-Object Name
  $rows = ''
  foreach($f in $files){
    $m = Get-MdMeta $f.FullName
    $rows += "<tr><td><code>$(HtmlEnc $m.id)</code></td><td>$(HtmlEnc $m.title)</td></tr>`n"
  }
  if(-not $rows){ $rows = "<tr><td colspan='2' class='empty'>(trống)</td></tr>" }
  @"
<section class="card">
  <h2>$label <span class="count">$($files.Count)</span></h2>
  <table><thead><tr><th>id</th><th>Tên</th></tr></thead><tbody>
$rows
  </tbody></table>
</section>
"@
}

$css = @"
<style>
:root{--bg:#0f172a;--card:#1e293b;--ink:#e2e8f0;--mut:#94a3b8;--ac:#38bdf8}
*{box-sizing:border-box}body{margin:0;font:15px/1.5 system-ui,Segoe UI,sans-serif;background:#f8fafc;color:#0f172a}
header{background:var(--bg);color:#fff;padding:28px 32px}
header h1{margin:0;font-size:22px}header p{margin:6px 0 0;color:#cbd5e1}
main{max-width:1000px;margin:24px auto;padding:0 20px;display:grid;gap:18px}
.card{background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:18px 20px;box-shadow:0 1px 3px rgba(0,0,0,.06)}
.card h2{margin:0 0 12px;font-size:17px;display:flex;align-items:center;gap:10px}
.count{background:var(--ac);color:#04293f;border-radius:999px;padding:1px 10px;font-size:13px;font-weight:700}
table{width:100%;border-collapse:collapse;font-size:14px}
th,td{text-align:left;padding:7px 10px;border-bottom:1px solid #eef2f7}
th{color:#64748b;font-weight:600;font-size:12px;text-transform:uppercase;letter-spacing:.04em}
code{background:#f1f5f9;padding:1px 6px;border-radius:6px;font-size:13px}
.empty{color:#94a3b8;font-style:italic}
.tree{font:13px/1.7 ui-monospace,Consolas,monospace;background:#0f172a;color:#cbd5e1;padding:14px 16px;border-radius:10px;white-space:pre;overflow:auto}
a{color:#0369a1}
.foot{color:#64748b;font-size:12px;text-align:center;margin:10px 0 30px}
</style>
"@

# ---------- knowledge/index.html ----------
$kc = Section-Md (Join-Path $root 'knowledge\concepts')      'Khái niệm'
$kp = Section-Md (Join-Path $root 'knowledge\problem-types') 'Dạng bài'
$km = Section-Md (Join-Path $root 'knowledge\methods')       'Phương pháp'
$kTree = @"
knowledge/
  concepts/       khái niệm — file tồn tại = ĐÃ BIẾT
  problem-types/  dạng bài — liên kết [[concept]] / [[method]] / [[neighbor]]
  methods/        phương pháp + điều kiện áp dụng
"@
$knowledge = @"
<!doctype html><html lang="vi"><head><meta charset="utf-8">
<title>Knowledge graph — PTĐHR</title>$css</head><body>
<header><h1>Knowledge graph — PTĐHR</h1>
<p>Tầng tri thức (md). Quy ước: <b>file khái niệm tồn tại = đã biết</b>. Cập nhật: chạy lại <code>tools\build-dashboards.ps1</code>.</p></header>
<main>
<section class="card"><h2>Cấu trúc thư mục</h2><div class="tree">$(HtmlEnc $kTree)</div></section>
$kc
$kp
$km
<p class="foot">Sinh tự động từ knowledge/ — không sửa tay file này.</p>
</main></body></html>
"@
Set-Content -Path (Join-Path $root 'knowledge\index.html') -Value $knowledge -Encoding utf8

# ---------- feedback/index.html ----------
$fb = Get-ChildItem (Join-Path $root 'feedback') -Filter *.html -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -ne 'index.html' } | Sort-Object Name -Descending
$frows = ''
foreach($f in $fb){
  $frows += "<tr><td><a href='$(HtmlEnc $f.Name)'>$(HtmlEnc $f.BaseName)</a></td><td>$($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))</td></tr>`n"
}
if(-not $frows){ $frows = "<tr><td colspan='2' class='empty'>(chưa có feedback nào — dùng #capture)</td></tr>" }

$caps = Get-ChildItem (Join-Path $root '.capture') -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
$crows = ''
foreach($c in $caps){
  $hasA = Test-Path (Join-Path $c.FullName 'analysis.json')
  $crows += "<tr><td><code>$(HtmlEnc $c.Name)</code></td><td>$(if($hasA){'✓ analysis.json'}else{'đang chạy / dở'})</td></tr>`n"
}
if(-not $crows){ $crows = "<tr><td colspan='2' class='empty'>(chưa có lần capture nào)</td></tr>" }

$feedback = @"
<!doctype html><html lang="vi"><head><meta charset="utf-8">
<title>Feedback — PTĐHR</title>$css</head><body>
<header><h1>Feedback — PTĐHR</h1>
<p>Trang HTML thảo luận (công thức render KaTeX) + nhật ký các lần capture.</p></header>
<main>
<section class="card"><h2>Trang feedback <span class="count">$($fb.Count)</span></h2>
<table><thead><tr><th>Trang</th><th>Cập nhật</th></tr></thead><tbody>$frows</tbody></table></section>
<section class="card"><h2>Lần capture <span class="count">$($caps.Count)</span></h2>
<table><thead><tr><th>slug</th><th>Trạng thái</th></tr></thead><tbody>$crows</tbody></table></section>
<p class="foot">Sinh tự động — chạy lại tools\build-dashboards.ps1 để cập nhật.</p>
</main></body></html>
"@
Set-Content -Path (Join-Path $root 'feedback\index.html') -Value $feedback -Encoding utf8

Write-Output "[dashboards] knowledge/index.html + feedback/index.html da cap nhat"
