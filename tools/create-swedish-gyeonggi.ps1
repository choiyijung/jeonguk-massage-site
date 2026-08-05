$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path $PSScriptRoot -Parent
$sourceRoot = Join-Path $projectRoot 'gyeonggi'
$targetRoot = Join-Path $projectRoot 'swedish\gyeonggi'
$utf8 = [System.Text.UTF8Encoding]::new($false)

if (-not (Test-Path -LiteralPath $sourceRoot)) {
    Write-Host "오류: 경기 일반 폴더를 찾을 수 없습니다: $sourceRoot"
    exit 1
}

$sourcePages = @(
    Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter 'index.html'
)

Write-Host ("변환 전 경기 일반 페이지: {0}개" -f $sourcePages.Count)

if ($sourcePages.Count -ne 658) {
    Write-Host "오류: 경기 일반 페이지가 658개가 아닙니다. 변환을 중단합니다."
    exit 1
}

if (Test-Path -LiteralPath $targetRoot) {
    $existingPages = @(
        Get-ChildItem -LiteralPath $targetRoot -Recurse -File -Filter 'index.html' -ErrorAction SilentlyContinue
    )

    if ($existingPages.Count -gt 0) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupRoot = "E:\jeonguk-스웨디시경기백업-$timestamp"
        Copy-Item -LiteralPath $targetRoot -Destination $backupRoot -Recurse -Force
        Write-Host "기존 스웨디시 경기 백업: $backupRoot"
    }

    Remove-Item -LiteralPath $targetRoot -Recurse -Force
}

$targetParent = Split-Path $targetRoot -Parent
New-Item -ItemType Directory -Force -Path $targetParent | Out-Null
New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
Get-ChildItem -LiteralPath $sourceRoot -Force | Copy-Item -Destination $targetRoot -Recurse -Force

$targetPages = @(
    Get-ChildItem -LiteralPath $targetRoot -Recurse -File -Filter 'index.html'
)

$modified = 0

foreach ($page in $targetPages) {
    $html = [System.IO.File]::ReadAllText($page.FullName)

    $html = $html.Replace('출장마사지와 스웨디시 정보를', '스웨디시 정보를')
    $html = $html.Replace('출장마사지와 스웨디시 정보', '스웨디시 정보')
    $html = $html.Replace('BUSINESS TRIP MASSAGE', 'SWEDISH MASSAGE')
    $html = $html.Replace('BUSINESS TRIP', 'SWEDISH')
    $html = $html.Replace('출장마사지', '스웨디시')

    $html = [regex]::Replace(
        $html,
        '(?<!/swedish)/gyeonggi/',
        '/swedish/gyeonggi/'
    )

    $html = $html.Replace('스웨디시와 스웨디시 정보를', '스웨디시 정보를')
    $html = $html.Replace('스웨디시와 스웨디시 정보', '스웨디시 정보')
    $html = $html.Replace('스웨디시와 스웨디시', '스웨디시')

    [System.IO.File]::WriteAllText($page.FullName, $html, $utf8)
    $modified++
}

$finalPages = @(
    Get-ChildItem -LiteralPath $targetRoot -Recurse -File -Filter 'index.html'
)

$remainingBusinessTrip = 0
$remainingKorean = 0
$badDoublePath = 0
$generalGyeonggiLinks = 0
$noindexCount = 0
$swedishTitleCount = 0
$duplicatePhraseCount = 0

foreach ($page in $finalPages) {
    $html = [System.IO.File]::ReadAllText($page.FullName)

    if ($html -match 'BUSINESS TRIP') { $remainingBusinessTrip++ }
    if ($html -match '출장마사지') { $remainingKorean++ }
    if ($html -match '/swedish/swedish/gyeonggi/') { $badDoublePath++ }
    if ($html -match 'href="/gyeonggi/') { $generalGyeonggiLinks++ }
    if ($html -match 'noindex,follow') { $noindexCount++ }
    if ($html -match '<title>[^<]*스웨디시') { $swedishTitleCount++ }
    if ($html -match '스웨디시와 스웨디시') { $duplicatePhraseCount++ }
}

Write-Host ""
Write-Host ("스웨디시 경기 전체 페이지: {0}개" -f $finalPages.Count)
Write-Host ("변환한 페이지: {0}개" -f $modified)
Write-Host ("스웨디시 제목 페이지: {0}개" -f $swedishTitleCount)
Write-Host ("noindex 동 페이지: {0}개" -f $noindexCount)
Write-Host ("남은 출장마사지 문구 페이지: {0}개" -f $remainingKorean)
Write-Host ("남은 BUSINESS TRIP 페이지: {0}개" -f $remainingBusinessTrip)
Write-Host ("일반 경기 내부 링크 남음: {0}개" -f $generalGyeonggiLinks)
Write-Host ("중복 스웨디시 경로: {0}개" -f $badDoublePath)
Write-Host ("중복 스웨디시 문구: {0}개" -f $duplicatePhraseCount)

if (
    $finalPages.Count -ne 658 -or
    $swedishTitleCount -ne 658 -or
    $noindexCount -ne 602 -or
    $remainingKorean -ne 0 -or
    $remainingBusinessTrip -ne 0 -or
    $generalGyeonggiLinks -ne 0 -or
    $badDoublePath -ne 0 -or
    $duplicatePhraseCount -ne 0
) {
    Write-Host ""
    Write-Host "오류: 변환 검사에서 확인할 항목이 발견됐습니다."
    exit 1
}

Write-Host ""
Write-Host "스웨디시 경기 변환 및 검사 완료"

