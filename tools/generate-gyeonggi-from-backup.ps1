param(
    [string]$DataFile = "$PSScriptRoot\gyeonggi-regions.json"
)

$projectRoot = Split-Path $PSScriptRoot -Parent
$seoulTemplate = "E:\jeonguk-서울지역창전체백업-20260805-145837\seoul\index.html"
$detailTemplate = "E:\jeonguk-서울지역창전체백업-20260805-145837\seoul\gangnam-gu\gaepo-1-dong\index.html"
$gyeonggiRoot = Join-Path $projectRoot "gyeonggi"
$utf8 = [System.Text.UTF8Encoding]::new($false)

if (-not (Test-Path $DataFile)) {
    Write-Host "오류: 경기 지역 데이터 파일을 찾을 수 없습니다."
    Write-Host $DataFile
    exit 1
}

if (-not (Test-Path $seoulTemplate)) {
    Write-Host "오류: 서울 기본 페이지를 찾을 수 없습니다."
    exit 1
}

if (-not (Test-Path $detailTemplate)) {
    Write-Host "오류: 동 상세 페이지 기본 파일을 찾을 수 없습니다."
    exit 1
}

function ConvertTo-Slug {
    param([Parameter(Mandatory = $true)][string]$Text)

    $initials = @(
        "g", "kk", "n", "d", "tt", "r", "m", "b", "pp",
        "s", "ss", "", "j", "jj", "ch", "k", "t", "p", "h"
    )

    $vowels = @(
        "a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o",
        "wa", "wae", "oe", "yo", "u", "wo", "we", "wi", "yu",
        "eu", "ui", "i"
    )

    $finals = @(
        "", "k", "k", "k", "n", "n", "n", "t", "l", "k",
        "m", "p", "l", "l", "p", "l", "m", "p", "p", "t",
        "t", "ng", "t", "t", "k", "t", "p", "h"
    )

    $builder = [System.Text.StringBuilder]::new()

    foreach ($char in $Text.Trim().ToCharArray()) {
        $code = [int][char]$char

        if ($code -ge 0xAC00 -and $code -le 0xD7A3) {
            $index = $code - 0xAC00
            $initialIndex = [int][math]::Floor($index / 588)
            $vowelIndex = [int][math]::Floor(($index % 588) / 28)
            $finalIndex = [int]($index % 28)

            [void]$builder.Append($initials[$initialIndex])
            [void]$builder.Append($vowels[$vowelIndex])
            [void]$builder.Append($finals[$finalIndex])
        }
        elseif ([char]::IsLetterOrDigit($char)) {
            [void]$builder.Append(([string]$char).ToLowerInvariant())
        }
        else {
            [void]$builder.Append("-")
        }
    }

    $slug = $builder.ToString()
    $slug = $slug -replace '([a-z])(\d)', '$1-$2'
    $slug = $slug -replace '(\d)([a-z])', '$1-$2'
    $slug = $slug -replace '-+', '-'
    $slug = $slug.Trim('-')

    return $slug
}

function Get-MunicipalitySlug {
    param([string]$Name)

    $baseName = $Name -replace '(특별자치시|광역시|특별시|시|군)$', ''
    return ConvertTo-Slug $baseName
}

function Get-UniqueSlug {
    param(
        [string]$Name,
        [string]$Code,
        [hashtable]$Used
    )

    $baseSlug = ConvertTo-Slug $Name
    $slug = $baseSlug

    if ($Used.ContainsKey($slug)) {
        $suffix = $Code
        if ($suffix.Length -gt 4) {
            $suffix = $suffix.Substring($suffix.Length - 4)
        }
        $slug = "$baseSlug-$suffix"
    }

    $Used[$slug] = $true
    return $slug
}

function New-CardHtml {
    param(
        [string]$Url,
        [string]$Name,
        [string]$Description
    )

    return @"
        <a class="region-card" href="$Url">
          <strong>$Name</strong>
          <span>$Description</span>
        </a>
"@
}

function New-ListingPage {
    param(
        [string]$OutputPath,
        [string]$Title,
        [string]$EnglishHeading,
        [string]$HeroTitle,
        [string]$SectionTitle,
        [string]$SectionDescription,
        [int]$ItemCount,
        [string[]]$Cards
    )

    $folder = Split-Path $OutputPath -Parent
    New-Item -ItemType Directory -Force $folder | Out-Null
    Copy-Item $seoulTemplate $OutputPath -Force

    $html = [System.IO.File]::ReadAllText($OutputPath)

    $html = [regex]::Replace(
        $html,
        '(?s)<title>.*?</title>',
        "<title>$Title</title>",
        1
    )

    $html = $html.Replace(
        'SEOUL BUSINESS TRIP MASSAGE',
        $EnglishHeading
    )

    $html = $html.Replace(
        '서울 출장마사지 지역 안내',
        $HeroTitle
    )

    $html = $html.Replace(
        '서울 구별 카테고리',
        $SectionTitle
    )

    $html = $html.Replace(
        '원하는 구를 선택하면 해당 지역의 동별 페이지로 연결됩니다.',
        $SectionDescription
    )

    $cardHtml = $Cards -join "`r`n"
    $pattern = '(?s)(<section id="business-trip".*?<div class="region-grid">).*?(</div>\s*</section>)'
    $replacement = '$1' + "`r`n" + $cardHtml + "`r`n      " + '$2'
    $html = [regex]::Replace($html, $pattern, $replacement, 1)

    $html = $html.Replace(
        '<span class="section-number">25</span>',
        "<span class=`"section-number`">$ItemCount</span>"
    )

    [System.IO.File]::WriteAllText($OutputPath, $html, $utf8)
}

function New-DongDetailPage {
    param(
        [pscustomobject]$Record,
        [string]$DongSlug,
        [string]$ParentFolder,
        [string]$ParentUrl,
        [string]$AreaName,
        [int]$AreaDongCount
    )

    $dongFolder = Join-Path $ParentFolder $DongSlug
    $dongIndex = Join-Path $dongFolder "index.html"
    $detailUrl = "$ParentUrl$DongSlug/"

    New-Item -ItemType Directory -Force $dongFolder | Out-Null
    Copy-Item $detailTemplate $dongIndex -Force

    $detailHtml = [System.IO.File]::ReadAllText($dongIndex)
    $englishDong = ($DongSlug -replace '-', ' ').ToUpper() + ' AREA GUIDE'

    $detailHtml = [regex]::Replace(
        $detailHtml,
        '(?s)<title>.*?</title>',
        "<title>$AreaName $($Record.dong) 출장마사지 | 지역 상세 안내</title>",
        1
    )

    $detailHtml = $detailHtml.Replace(
        '/seoul/gangnam-gu/gaepo-1-dong/',
        $detailUrl
    )

    $detailHtml = $detailHtml.Replace(
        '/seoul/gangnam-gu/',
        $ParentUrl
    )

    $detailHtml = $detailHtml.Replace(
        'GAEPO 1-DONG AREA GUIDE',
        $englishDong
    )

    $detailHtml = $detailHtml.Replace(
        '개포1동',
        $Record.dong
    )

    $detailHtml = $detailHtml.Replace(
        '강남구',
        $AreaName
    )

    $detailHtml = $detailHtml.Replace(
        '22개 동',
        "$AreaDongCount개 동"
    )

    if ($detailHtml -notmatch 'name="robots"') {
        $detailHtml = $detailHtml.Replace(
            '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
            "<meta name=`"viewport`" content=`"width=device-width, initial-scale=1.0`">`r`n  <meta name=`"robots`" content=`"noindex,follow`">"
        )
    }

    [System.IO.File]::WriteAllText($dongIndex, $detailHtml, $utf8)
}

$rawRegions = Get-Content $DataFile -Raw -Encoding UTF8 | ConvertFrom-Json

# Windows PowerShell 5.1에서는 JSON 배열이 한 개의 Object[]로 감싸질 수 있으므로
# 파이프라인을 한 번 통과시켜 602개 지역 객체로 확실하게 펼칩니다.
$regions = @(
    $rawRegions | ForEach-Object { $_ } | Sort-Object municipality, district, dong
)

if ($regions.Count -eq 0) {
    Write-Host "오류: 경기 지역 데이터가 비어 있습니다."
    exit 1
}

if ($regions.Count -eq 1 -and $regions[0] -is [System.Array]) {
    Write-Host "오류: 경기 지역 데이터가 하나의 배열로 묶여 있습니다."
    Write-Host "생성을 중단합니다."
    exit 1
}

$municipalityCheck = @(
    $regions | Select-Object -ExpandProperty municipality | Sort-Object -Unique
).Count

Write-Host ("생성 전 데이터 확인: 행정동 {0}개 / 시·군 {1}개" -f $regions.Count, $municipalityCheck)

if ($regions.Count -ne 602 -or $municipalityCheck -ne 31) {
    Write-Host "오류: 예상 데이터 수와 다릅니다. 생성을 중단합니다."
    exit 1
}

New-Item -ItemType Directory -Force $gyeonggiRoot | Out-Null

$municipalityNames = @(
    $regions.municipality |
    Sort-Object -Unique
)

$municipalitySlugMap = @{}
foreach ($municipalityName in $municipalityNames) {
    $municipalitySlugMap[$municipalityName] = Get-MunicipalitySlug $municipalityName
}

$mainCards = @(
    foreach ($municipalityName in $municipalityNames) {
        $municipalitySlug = $municipalitySlugMap[$municipalityName]
        New-CardHtml `
            -Url "/gyeonggi/$municipalitySlug/" `
            -Name $municipalityName `
            -Description "경기 지역 안내 보기"
    }
)

$gyeonggiIndex = Join-Path $gyeonggiRoot "index.html"
New-ListingPage `
    -OutputPath $gyeonggiIndex `
    -Title "경기 출장마사지 | 전국마사지 지역 안내" `
    -EnglishHeading "GYEONGGI BUSINESS TRIP MASSAGE" `
    -HeroTitle "경기 출장마사지 지역 안내" `
    -SectionTitle "경기 시·군별 카테고리" `
    -SectionDescription "원하는 시·군을 선택하면 해당 지역의 상세 페이지로 연결됩니다." `
    -ItemCount $municipalityNames.Count `
    -Cards $mainCards

$municipalityPageCount = 0
$districtPageCount = 0
$dongPageCount = 0

foreach ($municipalityName in $municipalityNames) {
    $municipalitySlug = $municipalitySlugMap[$municipalityName]
    $municipalityFolder = Join-Path $gyeonggiRoot $municipalitySlug
    $municipalityIndex = Join-Path $municipalityFolder "index.html"
    $municipalityRecords = @($regions | Where-Object { $_.municipality -eq $municipalityName })

    $districtNames = @(
        $municipalityRecords |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.district) } |
        Select-Object -ExpandProperty district |
        Sort-Object -Unique
    )

    $directDongs = @(
        $municipalityRecords |
        Where-Object { [string]::IsNullOrWhiteSpace($_.district) } |
        Sort-Object dong
    )

    $municipalityCards = @()

    foreach ($districtName in $districtNames) {
        $districtSlug = ConvertTo-Slug $districtName
        $municipalityCards += New-CardHtml `
            -Url "/gyeonggi/$municipalitySlug/$districtSlug/" `
            -Name $districtName `
            -Description "$municipalityName 지역 안내 보기"
    }

    $directSlugMap = @{}
    $usedDirectSlugs = @{}

    foreach ($record in $directDongs) {
        $dongSlug = Get-UniqueSlug -Name $record.dong -Code $record.code -Used $usedDirectSlugs
        $directSlugMap[$record.code] = $dongSlug
        $municipalityCards += New-CardHtml `
            -Url "/gyeonggi/$municipalitySlug/$dongSlug/" `
            -Name $record.dong `
            -Description "$municipalityName 지역 안내 보기"
    }

    if ($districtNames.Count -gt 0 -and $directDongs.Count -gt 0) {
        $sectionTitle = "$municipalityName 지역 카테고리"
        $sectionDescription = "원하는 구 또는 읍·면·동을 선택하면 상세 페이지로 연결됩니다."
    }
    elseif ($districtNames.Count -gt 0) {
        $sectionTitle = "$municipalityName 구별 카테고리"
        $sectionDescription = "원하는 구를 선택하면 해당 지역의 동별 페이지로 연결됩니다."
    }
    else {
        $sectionTitle = "$municipalityName 읍·면·동별 카테고리"
        $sectionDescription = "원하는 읍·면·동을 선택하면 해당 지역의 상세 페이지로 연결됩니다."
    }

    New-ListingPage `
        -OutputPath $municipalityIndex `
        -Title "$municipalityName 출장마사지 | 경기 지역 안내" `
        -EnglishHeading "$($municipalitySlug.ToUpper()) BUSINESS TRIP MASSAGE" `
        -HeroTitle "$municipalityName 출장마사지 지역 안내" `
        -SectionTitle $sectionTitle `
        -SectionDescription $sectionDescription `
        -ItemCount $municipalityCards.Count `
        -Cards $municipalityCards

    foreach ($record in $directDongs) {
        $dongSlug = $directSlugMap[$record.code]
        New-DongDetailPage `
            -Record $record `
            -DongSlug $dongSlug `
            -ParentFolder $municipalityFolder `
            -ParentUrl "/gyeonggi/$municipalitySlug/" `
            -AreaName $municipalityName `
            -AreaDongCount $directDongs.Count

        $dongPageCount++
    }

    foreach ($districtName in $districtNames) {
        $districtSlug = ConvertTo-Slug $districtName
        $districtFolder = Join-Path $municipalityFolder $districtSlug
        $districtIndex = Join-Path $districtFolder "index.html"
        $districtRecords = @(
            $municipalityRecords |
            Where-Object { $_.district -eq $districtName } |
            Sort-Object dong
        )

        $districtCards = @()
        $districtSlugMap = @{}
        $usedDistrictDongSlugs = @{}

        foreach ($record in $districtRecords) {
            $dongSlug = Get-UniqueSlug -Name $record.dong -Code $record.code -Used $usedDistrictDongSlugs
            $districtSlugMap[$record.code] = $dongSlug
            $districtCards += New-CardHtml `
                -Url "/gyeonggi/$municipalitySlug/$districtSlug/$dongSlug/" `
                -Name $record.dong `
                -Description "$municipalityName $districtName 지역 안내 보기"
        }

        New-ListingPage `
            -OutputPath $districtIndex `
            -Title "$municipalityName $districtName 출장마사지 | 동별 지역 안내" `
            -EnglishHeading "$($districtSlug.ToUpper()) BUSINESS TRIP MASSAGE" `
            -HeroTitle "$municipalityName $districtName 출장마사지 동별 안내" `
            -SectionTitle "$districtName 동별 카테고리" `
            -SectionDescription "원하는 동을 선택하면 해당 지역의 상세 페이지로 연결됩니다." `
            -ItemCount $districtRecords.Count `
            -Cards $districtCards

        foreach ($record in $districtRecords) {
            $dongSlug = $districtSlugMap[$record.code]
            New-DongDetailPage `
                -Record $record `
                -DongSlug $dongSlug `
                -ParentFolder $districtFolder `
                -ParentUrl "/gyeonggi/$municipalitySlug/$districtSlug/" `
                -AreaName "$municipalityName $districtName" `
                -AreaDongCount $districtRecords.Count

            $dongPageCount++
        }

        $districtPageCount++
        Write-Host "$municipalityName $districtName 생성 완료: $($districtRecords.Count)개 동"
    }

    $municipalityPageCount++
    Write-Host "$municipalityName 생성 완료"
}

$totalPageCount = @(
    [System.IO.Directory]::GetFiles(
        $gyeonggiRoot,
        "index.html",
        [System.IO.SearchOption]::AllDirectories
    )
).Count

Write-Host "--------------------------------"
Write-Host "경기 메인 페이지 생성 완료: 1개"
Write-Host ("경기 시·군 페이지 생성 완료: {0}개" -f $municipalityPageCount)
Write-Host ("경기 일반구 페이지 생성 완료: {0}개" -f $districtPageCount)
Write-Host ("경기 행정동 상세 페이지 생성 완료: {0}개" -f $dongPageCount)
Write-Host ("경기 전체 페이지 생성 완료: {0}개" -f $totalPageCount)

