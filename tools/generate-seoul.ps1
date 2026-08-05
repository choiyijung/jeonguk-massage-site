param(
    [string]$DataFile = "$PSScriptRoot\seoul-regions.json"
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$seoulTemplate = Join-Path $projectRoot "seoul\index.html"
$detailTemplate = Join-Path $projectRoot "seoul\gangnam-gu\gaepo-1-dong\index.html"

if (-not (Test-Path -LiteralPath $DataFile)) {
    Write-Host "오류: 서울 지역 데이터 파일이 없습니다."
    exit 1
}

if (-not (Test-Path -LiteralPath $seoulTemplate)) {
    Write-Host "오류: 서울 기본 페이지가 없습니다."
    exit 1
}

if (-not (Test-Path -LiteralPath $detailTemplate)) {
    Write-Host "오류: 동 상세 기본 페이지가 없습니다."
    exit 1
}

$regions = Get-Content -LiteralPath $DataFile -Raw -Encoding UTF8 |
    ConvertFrom-Json

$districtCount = 0
$dongCount = 0
$utf8Bom = New-Object System.Text.UTF8Encoding($true)

foreach ($district in $regions) {
    $districtSlug = [string]$district.slug
    $districtName = [string]$district.name
    $districtEnglish = [string]$district.english
    $dongs = @($district.dongs)
    $dongTotal = $dongs.Count

    $districtFolder = Join-Path $projectRoot "seoul\$districtSlug"
    $districtIndex = Join-Path $districtFolder "index.html"

    New-Item -ItemType Directory -Force $districtFolder | Out-Null
    Copy-Item $seoulTemplate $districtIndex -Force

    $html = [System.IO.File]::ReadAllText($districtIndex)

    $html = $html.Replace(
        "<title>서울 출장마사지 | 전국마사지 지역 안내</title>",
        "<title>$districtName 출장마사지 | 동별 지역 안내</title>"
    )

    $html = $html.Replace(
        "SEOUL BUSINESS TRIP MASSAGE",
        "$districtEnglish BUSINESS TRIP MASSAGE"
    )

    $html = $html.Replace(
        "서울 출장마사지 지역 안내",
        "$districtName 출장마사지 동별 안내"
    )

    $html = $html.Replace(
        "서울 구별 카테고리",
        "$districtName 동별 카테고리"
    )

    $html = $html.Replace(
        "원하는 구를 선택하면 해당 지역의 동별 페이지로 연결됩니다.",
        "원하는 동을 선택하면 해당 지역의 상세 페이지로 연결됩니다."
    )

    $cards = foreach ($dong in $dongs) {
@"
        <a class="region-card" href="/seoul/$districtSlug/$($dong.slug)/">
          <strong>$($dong.name)</strong>
          <span>$districtName 지역 안내 보기</span>
        </a>
"@
    }

    $cardHtml = $cards -join "`r`n"

    $pattern = '(?s)(<section id="business-trip".*?<div class="region-grid">).*?(</div>\s*</section>)'
    $replacement = '$1' + "`r`n" + $cardHtml + "`r`n      " + '$2'

    $html = [regex]::Replace(
        $html,
        $pattern,
        $replacement,
        1
    )

    $html = [regex]::Replace(
        $html,
        '<span class="section-number">\d+</span>',
        "<span class=`"section-number`">$dongTotal</span>",
        1
    )

    [System.IO.File]::WriteAllText(
        $districtIndex,
        $html,
        $utf8Bom
    )

    foreach ($dong in $dongs) {
        $dongSlug = [string]$dong.slug
        $dongName = [string]$dong.name

        $dongFolder = Join-Path $districtFolder $dongSlug
        $dongIndex = Join-Path $dongFolder "index.html"

        New-Item -ItemType Directory -Force $dongFolder | Out-Null
        Copy-Item $detailTemplate $dongIndex -Force

        $detailHtml = [System.IO.File]::ReadAllText($dongIndex)
        $englishDong = (($dongSlug -replace "-", " ").ToUpper()) + " AREA GUIDE"

        $detailHtml = $detailHtml.Replace(
            "GAEPO 1-DONG AREA GUIDE",
            $englishDong
        )

        $detailHtml = $detailHtml.Replace(
            "개포1동",
            $dongName
        )

        $detailHtml = $detailHtml.Replace(
            "강남구",
            $districtName
        )

        $detailHtml = $detailHtml.Replace(
            "/seoul/gangnam-gu/",
            "/seoul/$districtSlug/"
        )

        $detailHtml = $detailHtml.Replace(
            "22개 동",
            "$dongTotal개 동"
        )

        if ($detailHtml -notmatch 'name="robots"') {
            $viewport = '<meta name="viewport" content="width=device-width, initial-scale=1.0">'
            $robots = '<meta name="robots" content="noindex,follow">'

            $detailHtml = $detailHtml.Replace(
                $viewport,
                $viewport + "`r`n  " + $robots
            )
        }

        [System.IO.File]::WriteAllText(
            $dongIndex,
            $detailHtml,
            $utf8Bom
        )

        $dongCount++
    }

    $districtCount++
    Write-Host "$districtName 생성 완료: $dongTotal개 동"
}

Write-Host "--------------------------------"
Write-Host "서울 구 페이지 생성 완료: $districtCount개"
Write-Host "서울 동 상세 페이지 생성 완료: $dongCount개"
