param(
    [string]$DataFile = "$PSScriptRoot\seoul-regions.json"
)

$projectRoot = Split-Path $PSScriptRoot -Parent
$seoulTemplate = Join-Path $projectRoot "seoul\index.html"
$detailTemplate = Join-Path $projectRoot "seoul\gangnam-gu\gaepo-1-dong\index.html"

if (-not (Test-Path $DataFile)) {
    Write-Host "?ㅻ쪟: 吏???곗씠???뚯씪??李얠쓣 ???놁뒿?덈떎."
    Write-Host $DataFile
    exit 1
}

if (-not (Test-Path $seoulTemplate)) {
    Write-Host "?ㅻ쪟: ?쒖슱 湲곕낯 ?섏씠吏瑜?李얠쓣 ???놁뒿?덈떎."
    exit 1
}

if (-not (Test-Path $detailTemplate)) {
    Write-Host "?ㅻ쪟: ???곸꽭 ?섏씠吏 湲곕낯 ?뚯씪??李얠쓣 ???놁뒿?덈떎."
    exit 1
}

$regions = Get-Content $DataFile -Raw -Encoding UTF8 | ConvertFrom-Json

$districtCount = 0
$dongCount = 0

foreach ($district in $regions) {
    $districtFolder = Join-Path $projectRoot "seoul\$($district.slug)"
    $districtIndex = Join-Path $districtFolder "index.html"
    $numberOfDongs = $district.dongs.Count

    New-Item -ItemType Directory -Force $districtFolder | Out-Null
    Copy-Item $seoulTemplate $districtIndex -Force

    $html = [System.IO.File]::ReadAllText($districtIndex)

    $html = $html.Replace(
        '<title>?쒖슱 異쒖옣留덉궗吏 | ?꾧뎅留덉궗吏 吏???덈궡</title>',
        "<title>$($district.name) 異쒖옣留덉궗吏 | ?숇퀎 吏???덈궡</title>"
    )

    $html = $html.Replace(
        'SEOUL BUSINESS TRIP MASSAGE',
        "$($district.english) BUSINESS TRIP MASSAGE"
    )

    $html = $html.Replace(
        '?쒖슱 異쒖옣留덉궗吏 吏???덈궡',
        "$($district.name) 異쒖옣留덉궗吏 ?숇퀎 ?덈궡"
    )

    $html = $html.Replace(
        '?쒖슱 援щ퀎 移댄뀒怨좊━',
        "$($district.name) ?숇퀎 移댄뀒怨좊━"
    )

    $html = $html.Replace(
        '?먰븯??援щ? ?좏깮?섎㈃ ?대떦 吏??쓽 ?숇퀎 ?섏씠吏濡??곌껐?⑸땲??',
        '?먰븯???숈쓣 ?좏깮?섎㈃ ?대떦 吏??쓽 ?곸꽭 ?섏씠吏濡??곌껐?⑸땲??'
    )

    $cards = foreach ($dong in $district.dongs) {
@"
        <a class="region-card" href="/seoul/$($district.slug)/$($dong.slug)/">
          <strong>$($dong.name)</strong>
          <span>$($district.name) 吏???덈궡 蹂닿린</span>
        </a>
"@
    }

    $cardHtml = $cards -join "`r`n"

    $pattern = '(?s)(<section id="business-trip".*?<div class="region-grid">).*?(</div>\s*</section>)'
    $replacement = '$1' + "`r`n" + $cardHtml + "`r`n      " + '$2'

    $html = [regex]::Replace($html, $pattern, $replacement, 1)

    $html = $html.Replace(
        '<span class="section-number">25</span>',
        "<span class=`"section-number`">$numberOfDongs</span>"
    )

    [System.IO.File]::WriteAllText(
        $districtIndex,
        $html,
        [System.Text.UTF8Encoding]::new($false)
    )

    foreach ($dong in $district.dongs) {
        $dongFolder = Join-Path $districtFolder $dong.slug
        $dongIndex = Join-Path $dongFolder "index.html"

        New-Item -ItemType Directory -Force $dongFolder | Out-Null
        Copy-Item $detailTemplate $dongIndex -Force

        $detailHtml = [System.IO.File]::ReadAllText($dongIndex)
        $englishDong = ($dong.slug -replace "-", " ").ToUpper() + " AREA GUIDE"

        $detailHtml = $detailHtml.Replace(
            'GAEPO 1-DONG AREA GUIDE',
            $englishDong
        )

        $detailHtml = $detailHtml.Replace(
            '媛쒗룷1??,
            $dong.name
        )

        $detailHtml = $detailHtml.Replace(
            '媛뺣궓援?,
            $district.name
        )

        $detailHtml = $detailHtml.Replace(
            '/seoul/gangnam-gu/',
            "/seoul/$($district.slug)/"
        )

        $detailHtml = $detailHtml.Replace(
            '22媛???,
            "$numberOfDongs媛???
        )


        [System.IO.File]::WriteAllText(
            $dongIndex,
            $detailHtml,
            [System.Text.UTF8Encoding]::new($false)
        )

        $dongCount++
    }

    $districtCount++
    Write-Host "$($district.name) ?앹꽦 ?꾨즺: $numberOfDongs媛???
}

Write-Host "--------------------------------"
Write-Host "?쒖슱 援??섏씠吏 ?앹꽦 ?꾨즺: $districtCount媛?
Write-Host "?쒖슱 ???곸꽭 ?섏씠吏 ?앹꽦 ?꾨즺: $dongCount媛?
