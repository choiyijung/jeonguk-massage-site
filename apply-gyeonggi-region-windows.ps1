param(
    [switch]$ApplyAll
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if ((Split-Path $root -Leaf) -eq "tools") {
    $root = Split-Path $root -Parent
}

$cssPath = Join-Path $root "assets\css\style.css"
$urlSource = Join-Path $root "tools\지역주소_한번에연결.ps1"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$gyeonggiRootUrl = "https://www.gunmachonsa.shop/gyeonggi"
$generalBase = Join-Path $root "gyeonggi"
$swedishBase = Join-Path $root "swedish\gyeonggi"

if (-not (Test-Path -LiteralPath $cssPath)) {
    throw "공통 CSS 파일을 찾지 못했습니다: $cssPath"
}
if (-not (Test-Path -LiteralPath $urlSource)) {
    throw "URL 원본 파일을 찾지 못했습니다: $urlSource"
}
if (-not (Test-Path -LiteralPath $generalBase)) {
    throw "경기 일반 폴더를 찾지 못했습니다: $generalBase"
}
if (-not (Test-Path -LiteralPath $swedishBase)) {
    throw "경기 스웨디시 폴더를 찾지 못했습니다: $swedishBase"
}

$images = @(1..300 | ForEach-Object { "region-{0:D3}.png" -f $_ })
foreach ($image in $images) {
    $imagePath = Join-Path $root ("assets\images\" + $image)
    if (-not (Test-Path -LiteralPath $imagePath)) {
        throw "이미지를 찾지 못했습니다: $image"
    }
}

$generalPages = @(
    Get-ChildItem -LiteralPath $generalBase -Recurse -File -Filter "index.html" |
    Sort-Object FullName
)
$swedishPages = @(
    Get-ChildItem -LiteralPath $swedishBase -Recurse -File -Filter "index.html" |
    Sort-Object FullName
)

if ($generalPages.Count -ne 658) {
    throw "경기 일반 페이지 수가 예상과 다릅니다: $($generalPages.Count)"
}
if ($swedishPages.Count -ne 658) {
    throw "경기 스웨디시 페이지 수가 예상과 다릅니다: $($swedishPages.Count)"
}

$urlRaw = [System.IO.File]::ReadAllText($urlSource, [System.Text.Encoding]::UTF8)
$rawUrlMap = @{}

[regex]::Matches(
    $urlRaw,
    "Folder\s*=\s*'([^']+)';\s*Url\s*=\s*'([^']+)'"
) | ForEach-Object {
    $name = $_.Groups[1].Value.Trim()
    $url = $_.Groups[2].Value.Trim()

    if (-not $rawUrlMap.ContainsKey($name)) {
        $rawUrlMap[$name] = $url
    }
}

function Resolve-CityUrl {
    param([string]$CityName)

    $shortName = $CityName -replace '(특별자치시|시|군)$', ''

    if ($rawUrlMap.ContainsKey($CityName)) {
        return $rawUrlMap[$CityName]
    }

    if ($rawUrlMap.ContainsKey($shortName)) {
        return $rawUrlMap[$shortName]
    }

    throw "시·군 URL을 찾지 못했습니다: $CityName"
}

$cityFolderMap = @{}
$cityUrlMap = @{}

$cityFolders = @(
    Get-ChildItem -LiteralPath $generalBase -Directory |
    Sort-Object Name
)

foreach ($folder in $cityFolders) {
    $indexPath = Join-Path $folder.FullName "index.html"
    if (-not (Test-Path -LiteralPath $indexPath)) {
        throw "시·군 대표 페이지를 찾지 못했습니다: $indexPath"
    }

    $html = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
    $h1 = [regex]::Match($html, '<h1[^>]*>(.*?)</h1>', 'Singleline')

    if (-not $h1.Success) {
        throw "시·군 대표 페이지에서 h1을 찾지 못했습니다: $indexPath"
    }

    $title = ($h1.Groups[1].Value -replace '<[^>]+>', ' ').Trim()
    $nameMatch = [regex]::Match($title, '^(.+?)\s+(출장마사지|스웨디시)')

    if (-not $nameMatch.Success) {
        throw "시·군 이름을 확인하지 못했습니다: $indexPath"
    }

    $cityName = $nameMatch.Groups[1].Value.Trim()
    $cityUrl = Resolve-CityUrl $cityName

    $cityFolderMap[$folder.Name] = $cityName
    $cityUrlMap[$folder.Name] = $cityUrl
}

if ($cityFolderMap.Count -ne 31) {
    throw "경기 시·군 폴더 매칭 수가 예상과 다릅니다: $($cityFolderMap.Count)"
}

$imageByRelative = @{}
for ($i = 0; $i -lt $generalPages.Count; $i++) {
    $relative = $generalPages[$i].FullName.Substring($generalBase.Length).TrimStart('\')
    $imageByRelative[$relative] = $images[$i % 300]
}

function Get-PageInfo {
    param(
        [System.IO.FileInfo]$Page,
        [string]$Base,
        [string]$Service
    )

    $relative = $Page.FullName.Substring($Base.Length).TrimStart('\')
    $folderPart = Split-Path $relative -Parent
    $segments = @()

    if ($folderPart) {
        $segments = @($folderPart -split '\\')
    }

    $html = [System.IO.File]::ReadAllText($Page.FullName, [System.Text.Encoding]::UTF8)
    $h1 = [regex]::Match($html, '<h1[^>]*>(.*?)</h1>', 'Singleline')

    if (-not $h1.Success) {
        throw "h1을 찾지 못했습니다: $($Page.FullName)"
    }

    $title = ($h1.Groups[1].Value -replace '<[^>]+>', ' ').Trim()
    $nameMatch = [regex]::Match($title, '^(.+?)\s+(출장마사지|스웨디시)')
    $displayName = if ($nameMatch.Success) {
        $nameMatch.Groups[1].Value.Trim()
    } else {
        $title
    }

    if ($segments.Count -eq 0) {
        $pageType = "gyeonggi"
        $cityName = ""
        $url = $gyeonggiRootUrl
    } else {
        $cityFolder = $segments[0]

        if (-not $cityFolderMap.ContainsKey($cityFolder)) {
            throw "소속 시·군을 찾지 못했습니다: $($Page.FullName)"
        }

        $cityName = $cityFolderMap[$cityFolder]
        $url = $cityUrlMap[$cityFolder]

        if ($html -match 'noindex,follow') {
            $pageType = "dong"
        } elseif ($segments.Count -eq 1) {
            $pageType = "municipality"
        } else {
            $pageType = "district"
        }
    }

    [PSCustomObject]@{
        Page = $Page
        Html = $html
        Relative = $relative
        Service = $Service
        Title = $title
        DisplayName = $displayName
        CityName = $cityName
        PageType = $pageType
        Url = $url
        Image = $imageByRelative[$relative]
    }
}

$pageInfos = @()

foreach ($page in $generalPages) {
    $pageInfos += Get-PageInfo $page $generalBase "general"
}
foreach ($page in $swedishPages) {
    $pageInfos += Get-PageInfo $page $swedishBase "swedish"
}

if ($pageInfos.Count -ne 1316) {
    throw "전체 적용 대상 수가 예상과 다릅니다: $($pageInfos.Count)"
}

$trialRelative = "ansan\danwongu\baekundong\index.html"

if ($ApplyAll) {
    $targetInfos = @($pageInfos)
    $modeName = "전체"
} else {
    $targetInfos = @(
        $pageInfos |
        Where-Object { $_.Relative -eq $trialRelative }
    )
    $modeName = "시험"
}

if ($targetInfos.Count -eq 0) {
    throw "시험 적용 페이지를 찾지 못했습니다: $trialRelative"
}

foreach ($info in $targetInfos) {
    $hasOld = [regex]::IsMatch(
        $info.Html,
        '(?s)<section class="hero">.*?</section>'
    )
    $hasNew = [regex]::IsMatch(
        $info.Html,
        '(?s)<section class="region-window">.*?</section>'
    )

    if (-not $hasOld -and -not $hasNew) {
        throw "교체할 상단 영역을 찾지 못했습니다: $($info.Page.FullName)"
    }

    if (-not [regex]::IsMatch(
        $info.Html,
        '<section\s+id="swedish"\s+class="service-section swedish-section">'
    )) {
        throw "02번 시작 위치를 찾지 못했습니다: $($info.Page.FullName)"
    }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupName = if ($ApplyAll) {
    "jeonguk-경기지역창전체백업-$stamp"
} else {
    "jeonguk-경기지역창시험백업-$stamp"
}
$backupRoot = Join-Path (Split-Path $root -Parent) $backupName
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

foreach ($info in $targetInfos) {
    $relativeFromRoot = $info.Page.FullName.Substring($root.Length).TrimStart('\')
    $destination = Join-Path $backupRoot $relativeFromRoot

    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $info.Page.FullName -Destination $destination -Force
}

$cssBackup = Join-Path $backupRoot "assets\css\style.css"
New-Item -ItemType Directory -Path (Split-Path $cssBackup -Parent) -Force | Out-Null
Copy-Item -LiteralPath $cssPath -Destination $cssBackup -Force

$finalCss = @'

/* region-window-design:start */
.region-window{width:min(1180px,calc(100% - 40px));margin:38px auto 28px;padding:28px;display:grid;grid-template-columns:minmax(0,1.45fr) minmax(280px,.75fr);gap:30px;align-items:center;overflow:hidden;border:1px solid rgba(255,255,255,.14);border-radius:28px;background:linear-gradient(135deg,#241238 0%,#51206c 58%,#7a3f96 100%);box-shadow:0 20px 46px rgba(36,18,56,.22)}
.region-window__label{margin:0 0 12px;color:#f4c45e;font-size:13px;font-weight:900;letter-spacing:1.7px}
.region-window h1{margin:0;color:#fff;font-size:clamp(34px,5vw,58px);line-height:1.18;letter-spacing:-2.5px}
.region-window__text{max-width:680px;margin:20px 0 0;color:rgba(255,255,255,.83);font-size:17px;line-height:1.75}
.region-window__cta{display:block;width:100%;margin-top:22px;padding:16px 20px;border-radius:14px;background:linear-gradient(135deg,#ff981f,#f15c18);color:#fff;font-size:17px;font-weight:900;text-align:center;box-shadow:0 12px 26px rgba(241,92,24,.3);transition:transform .18s ease,filter .18s ease}
.region-window__cta:hover{transform:translateY(-2px);filter:brightness(1.05)}
.region-window__visual{min-height:300px;overflow:hidden;border-radius:22px;background:rgba(255,255,255,.1)}
.region-window__visual img{display:block;width:100%;height:100%;min-height:300px;object-fit:cover}
.section-external-cta{width:min(1180px,calc(100% - 40px));margin:0 auto 28px}
.section-external-cta .region-window__cta{margin-top:0}
@media(max-width:760px){.region-window{grid-template-columns:1fr;gap:20px;padding:20px}.region-window h1{font-size:34px;letter-spacing:-1.5px}.region-window__visual,.region-window__visual img{min-height:250px}}
/* region-window-design:end */
'@

$css = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)
$css = [regex]::Replace(
    $css,
    '(?s)\s*/\* region-window-test:start \*/.*?/\* region-window-test:end \*/',
    ''
)
$css = [regex]::Replace(
    $css,
    '(?s)\s*/\* region-window-design:start \*/.*?/\* region-window-design:end \*/',
    ''
)
$css = $css.TrimEnd() + "`r`n" + $finalCss + "`r`n"
[System.IO.File]::WriteAllText($cssPath, $css, $utf8)

$updated = 0

foreach ($info in $targetInfos) {
    $html = $info.Html

    $label = if ($info.Service -eq "swedish") {
        "전국마사지 경기 스웨디시 안내"
    } else {
        "전국마사지 경기 지역 안내"
    }

    $service = if ($info.Service -eq "swedish") {
        "스웨디시"
    } else {
        "출장마사지"
    }

    if ($info.PageType -eq "gyeonggi") {
        $description = "경기 31개 시·군과 세부 구·동별 $service 정보를 한눈에 확인하세요. 원하는 지역으로 빠르게 이동할 수 있도록 주요 카테고리와 바로가기를 정리했습니다."
    } elseif ($info.PageType -eq "municipality") {
        $description = "전국마사지에서 $($info.DisplayName) 생활권의 구·동별 $service 정보를 간편하게 확인하세요. 세부 지역 선택과 주변 카테고리를 보기 쉽게 정리했습니다."
    } elseif ($info.PageType -eq "district") {
        $description = "전국마사지에서 $($info.DisplayName)과 $($info.CityName) 생활권의 동별 $service 정보를 한눈에 확인하세요. 주변 지역 이동과 상세 카테고리를 보기 쉽게 정리했습니다."
    } else {
        $description = "전국마사지에서 $($info.DisplayName)과 $($info.CityName) 생활권의 $service 정보를 한눈에 확인하세요. 주변 지역 이동과 상세 카테고리를 보기 쉽게 정리했습니다."
    }

    $hero = @"
    <section class="region-window">
      <div class="region-window__copy">
        <p class="region-window__label">$label</p>
        <h1>$($info.Title)</h1>
        <p class="region-window__text">$description</p>
        <a class="region-window__cta" href="$($info.Url)" target="_blank" rel="nofollow noopener noreferrer">$($info.DisplayName) 인기업체 바로가기</a>
      </div>
      <div class="region-window__visual">
        <img src="/assets/images/$($info.Image)" alt="$($info.DisplayName) 전국마사지 지역 안내">
      </div>
    </section>
"@

    if ([regex]::IsMatch($html, '(?s)<section class="region-window">.*?</section>')) {
        $html = [regex]::Replace(
            $html,
            '(?s)<section class="region-window">.*?</section>',
            [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $hero },
            1
        )
    } else {
        $html = [regex]::Replace(
            $html,
            '(?s)<section class="hero">.*?</section>',
            [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $hero },
            1
        )
    }

    $html = [regex]::Replace(
        $html,
        '(?s)\s*<div class="section-external-cta">.*?</div>\s*',
        "`r`n"
    )

    $secondButton = @"
    <div class="section-external-cta">
      <a class="region-window__cta" href="$($info.Url)" target="_blank" rel="nofollow noopener noreferrer">$($info.DisplayName) 인기업체 바로가기</a>
    </div>

"@

    $html = [regex]::Replace(
        $html,
        '<section\s+id="swedish"\s+class="service-section swedish-section">',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($match)
            $secondButton + $match.Value
        },
        1
    )

    [System.IO.File]::WriteAllText($info.Page.FullName, $html, $utf8)
    $updated++
}

$windows = 0
$buttons = 0
$secondButtons = 0
$oldHeroes = 0
$badImages = 0
$badUrls = 0

foreach ($info in $targetInfos) {
    $html = [System.IO.File]::ReadAllText($info.Page.FullName, [System.Text.Encoding]::UTF8)

    $windows += [regex]::Matches($html, 'class="region-window"').Count
    $buttons += [regex]::Matches($html, 'class="region-window__cta"').Count
    $secondButtons += [regex]::Matches($html, 'class="section-external-cta"').Count
    $oldHeroes += [regex]::Matches($html, '<section class="hero">').Count

    $imageMatch = [regex]::Match(
        $html,
        '<img src="/assets/images/(region-\d{3}\.png)"'
    )

    if (
        -not $imageMatch.Success -or
        -not (Test-Path -LiteralPath (
            Join-Path $root ("assets\images\" + $imageMatch.Groups[1].Value)
        ))
    ) {
        $badImages++
    }

    $expectedUrlText = 'href="' + $info.Url + '"'
    if (
        ([regex]::Matches(
            $html,
            [regex]::Escape($expectedUrlText)
        ).Count) -ne 2
    ) {
        $badUrls++
    }
}

Write-Host ""
Write-Host ("경기 지역창 {0} 적용 완료" -f $modeName)
Write-Host "백업 폴더:" $backupRoot
Write-Host "수정 페이지:" $updated
Write-Host "지역창 수:" $windows
Write-Host "전체 주황버튼 수:" $buttons
Write-Host "02번 전 버튼 수:" $secondButtons
Write-Host "기존 hero 남음:" $oldHeroes
Write-Host "이미지 경로 확인 필요:" $badImages
Write-Host "URL 연결 확인 필요:" $badUrls
Write-Host "경기 대표 URL:" $gyeonggiRootUrl
Write-Host "경기 시·군 URL 수:" $cityUrlMap.Count
