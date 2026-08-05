param(
    [string]$DataFile = "$PSScriptRoot\daegu-regions.json"
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path $PSScriptRoot -Parent
$seoulTemplate = Join-Path $projectRoot 'seoul\index.html'
$detailTemplate = Join-Path $projectRoot 'seoul\gangnam-gu\gaepo-1-dong\index.html'
$targetRoot = Join-Path $projectRoot 'daegu'
$buildRoot = Join-Path $projectRoot '_daegu-build-temp'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$externalUrl = 'https://www.gunmachonsa.shop/daegu'
$siteBaseUrl = 'https://jeongukmassage.shop'

if (-not (Test-Path -LiteralPath $DataFile)) { throw "대구 데이터 파일을 찾지 못했습니다: $DataFile" }
if (-not (Test-Path -LiteralPath $seoulTemplate)) { throw "서울 대표 템플릿을 찾지 못했습니다: $seoulTemplate" }
if (-not (Test-Path -LiteralPath $detailTemplate)) { throw "서울 동 템플릿을 찾지 못했습니다: $detailTemplate" }

function ConvertTo-Slug {
    param([Parameter(Mandatory = $true)][string]$Text)

    $initials = @('g','kk','n','d','tt','r','m','b','pp','s','ss','','j','jj','ch','k','t','p','h')
    $vowels = @('a','ae','ya','yae','eo','e','yeo','ye','o','wa','wae','oe','yo','u','wo','we','wi','yu','eu','ui','i')
    $finals = @('','k','k','k','n','n','n','t','l','k','m','p','l','l','p','l','m','p','p','t','t','ng','t','t','k','t','p','h')
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
            [void]$builder.Append('-')
        }
    }

    $slug = $builder.ToString()
    $slug = $slug -replace '([a-z])(\d)', '$1-$2'
    $slug = $slug -replace '(\d)([a-z])', '$1-$2'
    $slug = $slug -replace '-+', '-'
    return $slug.Trim('-')
}

function Get-UniqueSlug {
    param([string]$Name,[string]$Code,[hashtable]$Used)
    $baseSlug = ConvertTo-Slug $Name
    $slug = $baseSlug
    if ($Used.ContainsKey($slug)) {
        $suffix = if ($Code.Length -gt 4) { $Code.Substring($Code.Length - 4) } else { $Code }
        $slug = "$baseSlug-$suffix"
    }
    $Used[$slug] = $true
    return $slug
}

function Set-PageMetadata {
    param([string]$Html,[string]$Title,[string]$Description,[string]$UrlPath)
    $absoluteUrl = $siteBaseUrl + $UrlPath
    $Html = [regex]::Replace($Html,'(?s)<title>.*?</title>',"<title>$Title</title>",1)
    $Html = [regex]::Replace($Html,'(?i)<meta\b(?=[^>]*\bname=["'']description["''])[^>]*>',"<meta name=`"description`" content=`"$Description`">",1)
    $Html = [regex]::Replace($Html,'(?i)<meta\b(?=[^>]*\bproperty=["'']og:title["''])[^>]*>',"<meta property=`"og:title`" content=`"$Title`">",1)
    $Html = [regex]::Replace($Html,'(?i)<meta\b(?=[^>]*\bproperty=["'']og:description["''])[^>]*>',"<meta property=`"og:description`" content=`"$Description`">",1)
    $Html = [regex]::Replace($Html,'(?i)<meta\b(?=[^>]*\bproperty=["'']og:url["''])[^>]*>',"<meta property=`"og:url`" content=`"$absoluteUrl`">",1)
    $Html = [regex]::Replace($Html,'(?i)<link\b(?=[^>]*\brel=["'']canonical["''])[^>]*>',"<link rel=`"canonical`" href=`"$absoluteUrl`">",1)
    return $Html
}

function Set-DaeguCtas {
    param([string]$Html,[string]$DisplayName)
    $Html = [regex]::Replace($Html,'href="https://www\.gunmachonsa\.shop/[^"]*"',('href="' + $externalUrl + '"'))
    $Html = [regex]::Replace(
        $Html,
        '(?s)(<a\b[^>]*class="region-window__cta"[^>]*>).*?(</a>)',
        ('$1' + $DisplayName + ' 인기업체 바로가기$2')
    )
    return $Html
}

function New-CardHtml {
    param([string]$Url,[string]$Name,[string]$Description)
    return @"
        <a class="region-card" href="$Url">
          <strong>$Name</strong>
          <span>$Description</span>
        </a>
"@
}

function New-ListingPage {
    param(
        [string]$OutputPath,[string]$UrlPath,[string]$Title,[string]$Description,
        [string]$HeroTitle,[string]$SectionTitle,[string]$SectionDescription,
        [int]$ItemCount,[string[]]$Cards,[string]$DisplayName
    )

    New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath -Parent) | Out-Null
    Copy-Item -LiteralPath $seoulTemplate -Destination $OutputPath -Force
    $html = [System.IO.File]::ReadAllText($OutputPath)
    $html = Set-PageMetadata -Html $html -Title $Title -Description $Description -UrlPath $UrlPath
    $html = [regex]::Replace($html,'(?s)<h1[^>]*>.*?</h1>',"<h1>$HeroTitle</h1>",1)
    $html = $html.Replace('SEOUL BUSINESS TRIP MASSAGE','DAEGU BUSINESS TRIP MASSAGE')
    $html = $html.Replace('서울 구별 카테고리',$SectionTitle)
    $html = $html.Replace('원하는 구를 선택하면 해당 지역의 동별 페이지로 연결됩니다.',$SectionDescription)

    $cardHtml = $Cards -join "`r`n"
    $pattern = '(?s)(<section id="business-trip".*?<div class="region-grid">).*?(</div>\s*</section>)'
    $replacement = '$1' + "`r`n" + $cardHtml + "`r`n      " + '$2'
    $html = [regex]::Replace($html,$pattern,$replacement,1)
    $html = [regex]::Replace($html,'<span class="section-number">\d+</span>',"<span class=`"section-number`">$ItemCount</span>",1)
    $html = Set-DaeguCtas -Html $html -DisplayName $DisplayName
    [System.IO.File]::WriteAllText($OutputPath,$html,$utf8)
}

function New-DongDetailPage {
    param(
        [pscustomobject]$Record,[string]$DongSlug,[string]$ParentFolder,
        [string]$ParentUrl,[string]$DistrictName,[int]$DistrictDongCount
    )

    $dongFolder = Join-Path $ParentFolder $DongSlug
    $dongIndex = Join-Path $dongFolder 'index.html'
    $detailUrl = "$ParentUrl$DongSlug/"
    $displayName = "대구 $DistrictName $($Record.dong)"
    $title = "$displayName 출장마사지 | 지역 상세 안내"
    $description = "$displayName 지역의 출장마사지 이용 정보와 주변 지역 이동 안내를 확인할 수 있습니다. 대구 구·군 및 읍·면·동별 카테고리를 함께 정리했습니다."

    New-Item -ItemType Directory -Force -Path $dongFolder | Out-Null
    Copy-Item -LiteralPath $detailTemplate -Destination $dongIndex -Force
    $html = [System.IO.File]::ReadAllText($dongIndex)
    $html = $html.Replace('/seoul/gangnam-gu/gaepo-1-dong/',$detailUrl)
    $html = $html.Replace('/seoul/gangnam-gu/',$ParentUrl)
    $html = $html.Replace('GAEPO 1-DONG AREA GUIDE',(($DongSlug -replace '-',' ').ToUpper() + ' AREA GUIDE'))
    $html = $html.Replace('개포1동',$Record.dong)
    $html = $html.Replace('강남구',"대구 $DistrictName")
    $html = $html.Replace('22개 동',"$DistrictDongCount개 읍·면·동")
    $html = Set-PageMetadata -Html $html -Title $title -Description $description -UrlPath $detailUrl
    $html = [regex]::Replace($html,'(?s)<h1[^>]*>.*?</h1>',"<h1>$displayName 출장마사지 지역 안내</h1>",1)
    $html = Set-DaeguCtas -Html $html -DisplayName $displayName

    if ($html -notmatch 'name="robots"') {
        $html = $html.Replace(
            '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
            "<meta name=`"viewport`" content=`"width=device-width, initial-scale=1.0`">`r`n  <meta name=`"robots`" content=`"noindex,follow`">"
        )
    }
    else {
        $html = [regex]::Replace($html,'(?i)<meta\b(?=[^>]*\bname=["'']robots["''])[^>]*>',"<meta name=`"robots`" content=`"noindex,follow`">",1)
    }

    [System.IO.File]::WriteAllText($dongIndex,$html,$utf8)
}

$regions = @(Get-Content -LiteralPath $DataFile -Raw -Encoding UTF8 | ConvertFrom-Json | ForEach-Object { $_ } | Sort-Object district,dong)
$districts = @($regions.district | Sort-Object -Unique)

Write-Host ("생성 전 데이터 확인: 읍·면·동 {0}개 / 구·군 {1}개" -f $regions.Count,$districts.Count)
if ($regions.Count -ne 150 -or $districts.Count -ne 9) { throw '대구 데이터 수가 예상과 다릅니다. 생성을 중단합니다.' }
if (@($regions | Group-Object code | Where-Object Count -gt 1).Count -ne 0) { throw '행정코드 중복이 있습니다.' }
if (@($regions | Where-Object { $_.dong -match '출장소$' }).Count -ne 0) { throw '출장소 항목이 남아 있습니다.' }

if (Test-Path -LiteralPath $buildRoot) { Remove-Item -LiteralPath $buildRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null

$districtSlugMap = @{}
foreach ($district in $districts) { $districtSlugMap[$district] = ConvertTo-Slug $district }

$rootCards = @(
    foreach ($district in $districts) {
        New-CardHtml -Url ("/daegu/{0}/" -f $districtSlugMap[$district]) -Name $district -Description '대구 지역 안내 보기'
    }
)

New-ListingPage `
    -OutputPath (Join-Path $buildRoot 'index.html') `
    -UrlPath '/daegu/' `
    -Title '대구 출장마사지 | 전국마사지 지역 안내' `
    -Description '대구 11개 구·군과 158개 읍·면·동별 출장마사지 지역 정보를 한눈에 확인할 수 있도록 정리했습니다.' `
    -HeroTitle '대구 출장마사지 지역 안내' `
    -SectionTitle '대구 구·군별 카테고리' `
    -SectionDescription '원하는 구·군을 선택하면 해당 지역의 읍·면·동별 페이지로 연결됩니다.' `
    -ItemCount $districts.Count `
    -Cards $rootCards `
    -DisplayName '대구'

$districtPageCount = 0
$dongPageCount = 0

foreach ($district in $districts) {
    $districtSlug = $districtSlugMap[$district]
    $districtFolder = Join-Path $buildRoot $districtSlug
    $districtUrl = "/daegu/$districtSlug/"
    $records = @($regions | Where-Object district -eq $district | Sort-Object dong)
    $used = @{}
    $slugMap = @{}
    $cards = @()

    foreach ($record in $records) {
        $dongSlug = Get-UniqueSlug -Name $record.dong -Code $record.code -Used $used
        $slugMap[$record.code] = $dongSlug
        $cards += New-CardHtml -Url ("$districtUrl$dongSlug/") -Name $record.dong -Description "$district 지역 안내 보기"
    }

    New-ListingPage `
        -OutputPath (Join-Path $districtFolder 'index.html') `
        -UrlPath $districtUrl `
        -Title "대구 $district 출장마사지 | 읍·면·동별 지역 안내" `
        -Description "대구 $district 소속 $($records.Count)개 읍·면·동별 출장마사지 지역 정보를 확인할 수 있도록 정리했습니다." `
        -HeroTitle "대구 $district 출장마사지 지역 안내" `
        -SectionTitle "$district 읍·면·동별 카테고리" `
        -SectionDescription '원하는 읍·면·동을 선택하면 해당 지역의 상세 페이지로 연결됩니다.' `
        -ItemCount $records.Count `
        -Cards $cards `
        -DisplayName "대구 $district"

    foreach ($record in $records) {
        New-DongDetailPage `
            -Record $record `
            -DongSlug $slugMap[$record.code] `
            -ParentFolder $districtFolder `
            -ParentUrl $districtUrl `
            -DistrictName $district `
            -DistrictDongCount $records.Count
        $dongPageCount++
    }

    $districtPageCount++
    Write-Host ("{0} 생성 완료: {1}개 읍·면·동" -f $district,$records.Count)
}

# DAEGU_CANONICAL_NORMALIZATION
$canonicalPages = @(
    Get-ChildItem -LiteralPath $buildRoot -Recurse -File -Filter 'index.html'
)

foreach ($canonicalPage in $canonicalPages) {
    $relativePath = $canonicalPage.FullName.Substring($buildRoot.Length)
    $relativePath = $relativePath.TrimStart('\').Replace('\','/')

    $urlPath = '/daegu/' + ($relativePath -replace 'index\.html$','')
    $urlPath = $urlPath -replace '/+','/'

    if (-not $urlPath.EndsWith('/')) {
        $urlPath += '/'
    }

    $canonicalUrl = $siteBaseUrl + $urlPath
    $pageHtml = [System.IO.File]::ReadAllText($canonicalPage.FullName)
    $canonicalPattern = '(?i)<link\b[^>]*\brel=["'']canonical["''][^>]*>'
    $canonicalTag = '<link rel="canonical" href="' + $canonicalUrl + '">'

    if ($pageHtml -match $canonicalPattern) {
        $pageHtml = [regex]::Replace(
            $pageHtml,
            $canonicalPattern,
            $canonicalTag,
            1
        )
    }
    else {
        $pageHtml = [regex]::Replace(
            $pageHtml,
            '(?i)</head>',
            ('  ' + $canonicalTag + "`r`n</head>"),
            1
        )
    }

    [System.IO.File]::WriteAllText(
        $canonicalPage.FullName,
        $pageHtml,
        $utf8
    )
}
# END_DAEGU_CANONICAL_NORMALIZATION
$pages = @(Get-ChildItem -LiteralPath $buildRoot -Recurse -File -Filter 'index.html')
$noindexPages = @($pages | Where-Object { [System.IO.File]::ReadAllText($_.FullName) -match 'noindex,follow' })
if ($pages.Count -ne 160) { throw "생성 페이지 수가 다릅니다: $($pages.Count)" }
if ($noindexPages.Count -ne 150) { throw "noindex 상세 페이지 수가 다릅니다: $($noindexPages.Count)" }

if (Test-Path -LiteralPath $targetRoot) {
    $existingPages = @(Get-ChildItem -LiteralPath $targetRoot -Recurse -File -Filter 'index.html' -ErrorAction SilentlyContinue)
    if ($existingPages.Count -gt 0) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupRoot = Join-Path (Split-Path $projectRoot -Parent) "jeonguk-대구생성전백업-$stamp"
        Copy-Item -LiteralPath $targetRoot -Destination $backupRoot -Recurse -Force
        Write-Host "기존 대구 백업: $backupRoot"
    }
    Remove-Item -LiteralPath $targetRoot -Recurse -Force
}
Move-Item -LiteralPath $buildRoot -Destination $targetRoot

Write-Host '--------------------------------'
Write-Host '대구 대표 페이지 생성 완료: 1개'
Write-Host ("대구 구·군 페이지 생성 완료: {0}개" -f $districtPageCount)
Write-Host ("대구 읍·면·동 상세 페이지 생성 완료: {0}개" -f $dongPageCount)
Write-Host ("대구 전체 페이지 생성 완료: {0}개" -f $pages.Count)
Write-Host ("noindex 상세 페이지: {0}개" -f $noindexPages.Count)
