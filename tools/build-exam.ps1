# Build exam/main.pdf. Scans exam/problem-types/<id>/prob.tex, regenerates _problems.tex,
# then compiles with xelatex (via latexmk). Run from anywhere.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$exam = Join-Path $root 'exam'

# Helper: gom các fragment theo CỤM (subfolder = cụm) thành tex, có \subsection* mỗi cụm.
#   $rel       : prefix đường dẫn \input (vd 'shared/concepts')
#   $clusterMap: ordered @{ folder = 'Nhãn hiển thị' }
#   $box       : $true -> bọc mỗi fragment trong ctbox (Phụ lục B/C); $false -> trơn (Phụ lục A)
function Build-Clustered($baseDir, $rel, $clusterMap, $box) {
  $blocks = @(); $total = 0; $ngroup = 0
  foreach ($key in $clusterMap.Keys) {
    $files = Get-ChildItem (Join-Path $baseDir $key) -Filter *.tex -File -ErrorAction SilentlyContinue | Sort-Object Name
    if (-not $files) { continue }
    $total += $files.Count; $ngroup++
    $inputs = foreach ($f in $files) {
      if ($box) { "\begin{ctbox}\input{$rel/$key/$($f.BaseName).tex}\end{ctbox}" }
      else      { "\input{$rel/$key/$($f.BaseName).tex}" }
    }
    $sep = if ($box) { "`n`n\smallskip`n`n" } else { "`n`n\medskip`n`n" }
    $blocks += "\subsection*{$($clusterMap[$key])}`n" + ($inputs -join $sep)
  }
  return [pscustomobject]@{ Tex = ($blocks -join "`n`n\bigskip`n`n"); Total = $total; Groups = $ngroup }
}

# 1a. _concepts.tex — Phụ lục A (Khái niệm): 5 cụm, trơn (không box)
$conceptClusters = [ordered]@{
  'bai-toan'   = 'Lớp bài toán'
  'loai-pt'    = 'Loại phương trình \& toán tử'
  'lan-truyen' = 'Tính chất lan truyền sóng'
  'du-lieu'    = 'Dữ liệu \& nghiệm'
  'ham'        = 'Hàm hay dùng'
}
$a = Build-Clustered (Join-Path $exam 'shared\concepts') 'shared/concepts' $conceptClusters $false
Set-Content -Path (Join-Path $exam '_concepts.tex') -Value $a.Tex -Encoding utf8
Write-Output "[build] _concepts.tex: $($a.Total) khái niệm / $($a.Groups) cụm (Phụ lục A)"

# 1a'. _integrals.tex — Phụ lục B (Công thức & tích phân thường gặp): 3 nhóm, mỗi mục bọc ctbox
$formulaGroups = [ordered]@{
  'luong-giac'    = 'Công thức lượng giác'
  'gauss'         = 'Tích phân Gauss \& hàm sai số'
  'mat-cau'       = 'Hình học mặt cầu'
  'toa-do'        = 'Laplacian theo tọa độ'
  'nghiem-co-ban' = 'Nghiệm cơ bản \& nhân nhiệt'
  'green'         = 'Đẳng thức Green'
}
$b = Build-Clustered (Join-Path $exam 'shared\integrals') 'shared/integrals' $formulaGroups $true
Set-Content -Path (Join-Path $exam '_integrals.tex') -Value $b.Tex -Encoding utf8
Write-Output "[build] _integrals.tex: $($b.Total) công thức / $($b.Groups) nhóm (Phụ lục B)"

# 1a''. _techniques.tex — Phụ lục C (Kỹ thuật tính toán): các fragment trong shared/techniques, mỗi mục ctbox
$techs = Get-ChildItem (Join-Path $exam 'shared\techniques') -Filter *.tex -File -ErrorAction SilentlyContinue |
         Sort-Object Name
$tlines = foreach ($t in $techs) { "\begin{ctbox}\input{shared/techniques/$($t.BaseName).tex}\end{ctbox}" }
$tcontent = if ($tlines) { $tlines -join "`n`n\smallskip`n`n" } else { "" }
Set-Content -Path (Join-Path $exam '_techniques.tex') -Value $tcontent -Encoding utf8
Write-Output "[build] _techniques.tex: $($techs.Count) kỹ thuật (Phụ lục C)"

# 1b. Regenerate _problems.tex — sắp theo metadata "% order: N" trong prob.tex (rồi đến tên).
#     Dạng bài KHÔNG có order -> mặc định 999 (xuống cuối). Cho phép xếp theo Ý NGHĨA, không alphabet.
$probs = Get-ChildItem (Join-Path $exam 'problem-types') -Directory -ErrorAction SilentlyContinue |
         Where-Object { Test-Path (Join-Path $_.FullName 'prob.tex') } |
         ForEach-Object {
           $head = Get-Content (Join-Path $_.FullName 'prob.tex') -Encoding utf8 -TotalCount 8
           $ord = 999
           foreach ($l in $head) { if ($l -match '%\s*order:\s*(\d+)') { $ord = [int]$Matches[1]; break } }
           [pscustomobject]@{ Name=$_.Name; Order=$ord }
         } |
         Sort-Object Order, Name
$lines = foreach ($p in $probs) { "\input{problem-types/$($p.Name)/prob.tex}" }
$content = if ($lines) { $lines -join "`n" } else { "" }
Set-Content -Path (Join-Path $exam '_problems.tex') -Value $content -Encoding utf8
Write-Output "[build] _problems.tex: $($probs.Count) dạng bài (sắp theo % order)"

# 2. Compile with xelatex directly, twice (latexmk needs perl; xelatex does not).
#    Pass 1 builds .toc, pass 2 resolves the table of contents.
$xelatex = (Get-Command xelatex -ErrorAction SilentlyContinue).Source
if (-not $xelatex) {
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\MiKTeX\miktex\bin\x64\xelatex.exe",
    'C:\Users\lbmin\AppData\Local\Programs\MiKTeX\miktex\bin\x64\xelatex.exe'
  )
  $xelatex = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $xelatex) { Write-Output "[build] xelatex not found on PATH"; exit 1 }
Push-Location $exam
try {
  & $xelatex -interaction=nonstopmode -halt-on-error main.tex | Out-Null
  & $xelatex -interaction=nonstopmode -halt-on-error main.tex | Out-Null
  $code = $LASTEXITCODE
} finally { Pop-Location }

$pdf = Join-Path $exam 'main.pdf'
if ($code -eq 0 -and (Test-Path $pdf)) {
  Write-Output "[build] OK -> $pdf"
} else {
  Write-Output "[build] FAILED (exit=$code). Xem exam\main.log"
}
