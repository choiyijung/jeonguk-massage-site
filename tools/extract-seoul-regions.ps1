$sourcePath = Join-Path $PSScriptRoot "seoul-official.html"
$outputPath = Join-Path $PSScriptRoot "seoul-regions.json"

if (-not (Test-Path -LiteralPath $sourcePath)) {
    Write-Host "오류: 서울시 공식 자료 파일을 찾을 수 없습니다."
    exit 1
}

Add-Type -AssemblyName System.Web

$html = Get-Content `
    -LiteralPath $sourcePath `
    -Raw `
    -Encoding UTF8

$districtSlugs = [ordered]@{
    "강남구"     = "gangnam-gu"
    "강동구"     = "gangdong-gu"
    "강북구"     = "gangbuk-gu"
    "강서구"     = "gangseo-gu"
    "관악구"     = "gwanak-gu"
    "광진구"     = "gwangjin-gu"
    "구로구"     = "guro-gu"
    "금천구"     = "geumcheon-gu"
    "노원구"     = "nowon-gu"
    "도봉구"     = "dobong-gu"
    "동대문구"   = "dongdaemun-gu"
    "동작구"     = "dongjak-gu"
    "마포구"     = "mapo-gu"
    "서대문구"   = "seodaemun-gu"
    "서초구"     = "seocho-gu"
    "성동구"     = "seongdong-gu"
    "성북구"     = "seongbuk-gu"
    "송파구"     = "songpa-gu"
    "양천구"     = "yangcheon-gu"
    "영등포구"   = "yeongdeungpo-gu"
    "용산구"     = "yongsan-gu"
    "은평구"     = "eunpyeong-gu"
    "종로구"     = "jongno-gu"
    "중구"       = "jung-gu"
    "중랑구"     = "jungnang-gu"
}

$completedDistricts = @(
    "강남구",
    "강동구",
    "강북구",
    "강서구"
)

function Convert-ToDongSlug {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $initial = @(
        "g","kk","n","d","tt","r","m","b","pp",
        "s","ss","","j","jj","ch","k","t","p","h"
    )

    $vowel = @(
        "a","ae","ya","yae","eo","e","yeo","ye",
        "o","wa","wae","oe","yo","u","wo","we",
        "wi","yu","eu","ui","i"
    )

    $final = @(
        "","k","k","k","n","n","n","t","l","k",
        "m","l","l","l","p","l","m","p","p","t",
        "t","ng","t","t","k","t","p","h"
    )

    $baseName = $Name

    if ($baseName.EndsWith("동")) {
        $baseName = $baseName.Substring(0, $baseName.Length - 1)
    }

    $result = ""

    foreach ($character in $baseName.ToCharArray()) {
        $code = [int][char]$character

        if ($code -ge 0xAC00 -and $code -le 0xD7A3) {
            $value = $code - 0xAC00

            $initialIndex = [int]($value / 588)
            $vowelIndex = [int](($value % 588) / 28)
            $finalIndex = $value % 28

            $result += $initial[$initialIndex]
            $result += $vowel[$vowelIndex]
            $result += $final[$finalIndex]
        }
        elseif ([char]::IsDigit($character)) {
            $result += [string]$character
        }
        elseif ($character -eq "," -or $character -eq "·") {
            $result += "-"
        }
    }

    $result = $result -replace '(?<=[a-z])(?=\d)', '-'
    $result = $result -replace '-+', '-'
    $result = $result.Trim("-")

    return "$result-dong"
}

$districtPattern = [regex]::new(
    '(?is)(?<number>\d{1,2})\)\s*(?<name>[가-힣]+구).*?<table[^>]*>(?<table>.*?)</table>'
)

$rowPattern = [regex]::new(
    '(?is)<tr[^>]*>\s*<td[^>]*>(?<admin>.*?)</td>\s*<td[^>]*>'
)

$regions = @()

foreach ($districtMatch in $districtPattern.Matches($html)) {
    $districtName = $districtMatch.Groups["name"].Value.Trim()

    if (-not $districtSlugs.Contains($districtName)) {
        continue
    }

    if ($completedDistricts -contains $districtName) {
        continue
    }

    $districtSlug = $districtSlugs[$districtName]
    $districtEnglish = ($districtSlug -replace '-gu$', '').ToUpper()
    $tableHtml = $districtMatch.Groups["table"].Value

    $dongs = @()
    $usedSlugs = @{}

    foreach ($rowMatch in $rowPattern.Matches($tableHtml)) {
        $adminHtml = $rowMatch.Groups["admin"].Value

        $adminName = [regex]::Replace(
            $adminHtml,
            '<[^>]+>',
            ''
        )

        $adminName = [System.Web.HttpUtility]::HtmlDecode($adminName)
        $adminName = $adminName -replace '\s+', ''
        $adminName = $adminName -replace '\([^)]*\)', ''
        $adminName = $adminName.Trim()

        if ($adminName -notmatch '동$') {
            continue
        }

        $slug = Convert-ToDongSlug -Name $adminName
        $originalSlug = $slug
        $duplicateNumber = 2

        while ($usedSlugs.ContainsKey($slug)) {
            $slug = "$originalSlug-$duplicateNumber"
            $duplicateNumber++
        }

        $usedSlugs[$slug] = $true

        $dongs += [ordered]@{
            slug = $slug
            name = $adminName
        }
    }

    $regions += [ordered]@{
        slug    = $districtSlug
        name    = $districtName
        english = $districtEnglish
        dongs   = $dongs
    }

    Write-Host "$districtName 추출 완료: $($dongs.Count)개 동"
}

if (-not ($regions | Where-Object { $_.name -eq "서대문구" })) {
    $regions += [ordered]@{
        slug    = "seodaemun-gu"
        name    = "서대문구"
        english = "SEODAEMUN"
        dongs   = @(
            [ordered]@{ slug = "chunghyeon-dong";  name = "충현동" }
            [ordered]@{ slug = "cheonyeon-dong";   name = "천연동" }
            [ordered]@{ slug = "bukahyeon-dong";   name = "북아현동" }
            [ordered]@{ slug = "sinchon-dong";     name = "신촌동" }
            [ordered]@{ slug = "yeonhui-dong";     name = "연희동" }
            [ordered]@{ slug = "hongje-1-dong";    name = "홍제1동" }
            [ordered]@{ slug = "hongje-2-dong";    name = "홍제2동" }
            [ordered]@{ slug = "hongje-3-dong";    name = "홍제3동" }
            [ordered]@{ slug = "hongeun-1-dong";   name = "홍은1동" }
            [ordered]@{ slug = "hongeun-2-dong";   name = "홍은2동" }
            [ordered]@{ slug = "namgajwa-1-dong";  name = "남가좌1동" }
            [ordered]@{ slug = "namgajwa-2-dong";  name = "남가좌2동" }
            [ordered]@{ slug = "bukgajwa-1-dong";  name = "북가좌1동" }
            [ordered]@{ slug = "bukgajwa-2-dong";  name = "북가좌2동" }
        )
    }

    Write-Host "서대문구 보완 완료: 14개 동"
}

if (-not ($regions | Where-Object { $sourcePath = Join-Path $PSScriptRoot "seoul-official.html"
$outputPath = Join-Path $PSScriptRoot "seoul-regions.json"

if (-not (Test-Path -LiteralPath $sourcePath)) {
    Write-Host "오류: 서울시 공식 자료 파일을 찾을 수 없습니다."
    exit 1
}

Add-Type -AssemblyName System.Web

$html = Get-Content `
    -LiteralPath $sourcePath `
    -Raw `
    -Encoding UTF8

$districtSlugs = [ordered]@{
    "강남구"     = "gangnam-gu"
    "강동구"     = "gangdong-gu"
    "강북구"     = "gangbuk-gu"
    "강서구"     = "gangseo-gu"
    "관악구"     = "gwanak-gu"
    "광진구"     = "gwangjin-gu"
    "구로구"     = "guro-gu"
    "금천구"     = "geumcheon-gu"
    "노원구"     = "nowon-gu"
    "도봉구"     = "dobong-gu"
    "동대문구"   = "dongdaemun-gu"
    "동작구"     = "dongjak-gu"
    "마포구"     = "mapo-gu"
    "서대문구"   = "seodaemun-gu"
    "서초구"     = "seocho-gu"
    "성동구"     = "seongdong-gu"
    "성북구"     = "seongbuk-gu"
    "송파구"     = "songpa-gu"
    "양천구"     = "yangcheon-gu"
    "영등포구"   = "yeongdeungpo-gu"
    "용산구"     = "yongsan-gu"
    "은평구"     = "eunpyeong-gu"
    "종로구"     = "jongno-gu"
    "중구"       = "jung-gu"
    "중랑구"     = "jungnang-gu"
}

$completedDistricts = @(
    "강남구",
    "강동구",
    "강북구",
    "강서구"
)

function Convert-ToDongSlug {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $initial = @(
        "g","kk","n","d","tt","r","m","b","pp",
        "s","ss","","j","jj","ch","k","t","p","h"
    )

    $vowel = @(
        "a","ae","ya","yae","eo","e","yeo","ye",
        "o","wa","wae","oe","yo","u","wo","we",
        "wi","yu","eu","ui","i"
    )

    $final = @(
        "","k","k","k","n","n","n","t","l","k",
        "m","l","l","l","p","l","m","p","p","t",
        "t","ng","t","t","k","t","p","h"
    )

    $baseName = $Name

    if ($baseName.EndsWith("동")) {
        $baseName = $baseName.Substring(0, $baseName.Length - 1)
    }

    $result = ""

    foreach ($character in $baseName.ToCharArray()) {
        $code = [int][char]$character

        if ($code -ge 0xAC00 -and $code -le 0xD7A3) {
            $value = $code - 0xAC00

            $initialIndex = [int]($value / 588)
            $vowelIndex = [int](($value % 588) / 28)
            $finalIndex = $value % 28

            $result += $initial[$initialIndex]
            $result += $vowel[$vowelIndex]
            $result += $final[$finalIndex]
        }
        elseif ([char]::IsDigit($character)) {
            $result += [string]$character
        }
        elseif ($character -eq "," -or $character -eq "·") {
            $result += "-"
        }
    }

    $result = $result -replace '(?<=[a-z])(?=\d)', '-'
    $result = $result -replace '-+', '-'
    $result = $result.Trim("-")

    return "$result-dong"
}

$districtPattern = [regex]::new(
    '(?is)(?<number>\d{1,2})\)\s*(?<name>[가-힣]+구).*?<table[^>]*>(?<table>.*?)</table>'
)

$rowPattern = [regex]::new(
    '(?is)<tr[^>]*>\s*<td[^>]*>(?<admin>.*?)</td>\s*<td[^>]*>'
)

$regions = @()

foreach ($districtMatch in $districtPattern.Matches($html)) {
    $districtName = $districtMatch.Groups["name"].Value.Trim()

    if (-not $districtSlugs.Contains($districtName)) {
        continue
    }

    if ($completedDistricts -contains $districtName) {
        continue
    }

    $districtSlug = $districtSlugs[$districtName]
    $districtEnglish = ($districtSlug -replace '-gu$', '').ToUpper()
    $tableHtml = $districtMatch.Groups["table"].Value

    $dongs = @()
    $usedSlugs = @{}

    foreach ($rowMatch in $rowPattern.Matches($tableHtml)) {
        $adminHtml = $rowMatch.Groups["admin"].Value

        $adminName = [regex]::Replace(
            $adminHtml,
            '<[^>]+>',
            ''
        )

        $adminName = [System.Web.HttpUtility]::HtmlDecode($adminName)
        $adminName = $adminName -replace '\s+', ''
        $adminName = $adminName -replace '\([^)]*\)', ''
        $adminName = $adminName.Trim()

        if ($adminName -notmatch '동$') {
            continue
        }

        $slug = Convert-ToDongSlug -Name $adminName
        $originalSlug = $slug
        $duplicateNumber = 2

        while ($usedSlugs.ContainsKey($slug)) {
            $slug = "$originalSlug-$duplicateNumber"
            $duplicateNumber++
        }

        $usedSlugs[$slug] = $true

        $dongs += [ordered]@{
            slug = $slug
            name = $adminName
        }
    }

    $regions += [ordered]@{
        slug    = $districtSlug
        name    = $districtName
        english = $districtEnglish
        dongs   = $dongs
    }

    Write-Host "$districtName 추출 완료: $($dongs.Count)개 동"
}

if (-not ($regions | Where-Object { $_.name -eq "서대문구" })) {
    $regions += [ordered]@{
        slug    = "seodaemun-gu"
        name    = "서대문구"
        english = "SEODAEMUN"
        dongs   = @(
            [ordered]@{ slug = "chunghyeon-dong";  name = "충현동" }
            [ordered]@{ slug = "cheonyeon-dong";   name = "천연동" }
            [ordered]@{ slug = "bukahyeon-dong";   name = "북아현동" }
            [ordered]@{ slug = "sinchon-dong";     name = "신촌동" }
            [ordered]@{ slug = "yeonhui-dong";     name = "연희동" }
            [ordered]@{ slug = "hongje-1-dong";    name = "홍제1동" }
            [ordered]@{ slug = "hongje-2-dong";    name = "홍제2동" }
            [ordered]@{ slug = "hongje-3-dong";    name = "홍제3동" }
            [ordered]@{ slug = "hongeun-1-dong";   name = "홍은1동" }
            [ordered]@{ slug = "hongeun-2-dong";   name = "홍은2동" }
            [ordered]@{ slug = "namgajwa-1-dong";  name = "남가좌1동" }
            [ordered]@{ slug = "namgajwa-2-dong";  name = "남가좌2동" }
            [ordered]@{ slug = "bukgajwa-1-dong";  name = "북가좌1동" }
            [ordered]@{ slug = "bukgajwa-2-dong";  name = "북가좌2동" }
        )
    }

    Write-Host "서대문구 보완 완료: 14개 동"
}
# SEODAEMUN-FALLBACK
if (-not ($regions | Where-Object { $sourcePath = Join-Path $PSScriptRoot "seoul-official.html"
$outputPath = Join-Path $PSScriptRoot "seoul-regions.json"

if (-not (Test-Path -LiteralPath $sourcePath)) {
    Write-Host "오류: 서울시 공식 자료 파일을 찾을 수 없습니다."
    exit 1
}

Add-Type -AssemblyName System.Web

$html = Get-Content `
    -LiteralPath $sourcePath `
    -Raw `
    -Encoding UTF8

$districtSlugs = [ordered]@{
    "강남구"     = "gangnam-gu"
    "강동구"     = "gangdong-gu"
    "강북구"     = "gangbuk-gu"
    "강서구"     = "gangseo-gu"
    "관악구"     = "gwanak-gu"
    "광진구"     = "gwangjin-gu"
    "구로구"     = "guro-gu"
    "금천구"     = "geumcheon-gu"
    "노원구"     = "nowon-gu"
    "도봉구"     = "dobong-gu"
    "동대문구"   = "dongdaemun-gu"
    "동작구"     = "dongjak-gu"
    "마포구"     = "mapo-gu"
    "서대문구"   = "seodaemun-gu"
    "서초구"     = "seocho-gu"
    "성동구"     = "seongdong-gu"
    "성북구"     = "seongbuk-gu"
    "송파구"     = "songpa-gu"
    "양천구"     = "yangcheon-gu"
    "영등포구"   = "yeongdeungpo-gu"
    "용산구"     = "yongsan-gu"
    "은평구"     = "eunpyeong-gu"
    "종로구"     = "jongno-gu"
    "중구"       = "jung-gu"
    "중랑구"     = "jungnang-gu"
}

$completedDistricts = @(
    "강남구",
    "강동구",
    "강북구",
    "강서구"
)

function Convert-ToDongSlug {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $initial = @(
        "g","kk","n","d","tt","r","m","b","pp",
        "s","ss","","j","jj","ch","k","t","p","h"
    )

    $vowel = @(
        "a","ae","ya","yae","eo","e","yeo","ye",
        "o","wa","wae","oe","yo","u","wo","we",
        "wi","yu","eu","ui","i"
    )

    $final = @(
        "","k","k","k","n","n","n","t","l","k",
        "m","l","l","l","p","l","m","p","p","t",
        "t","ng","t","t","k","t","p","h"
    )

    $baseName = $Name

    if ($baseName.EndsWith("동")) {
        $baseName = $baseName.Substring(0, $baseName.Length - 1)
    }

    $result = ""

    foreach ($character in $baseName.ToCharArray()) {
        $code = [int][char]$character

        if ($code -ge 0xAC00 -and $code -le 0xD7A3) {
            $value = $code - 0xAC00

            $initialIndex = [int]($value / 588)
            $vowelIndex = [int](($value % 588) / 28)
            $finalIndex = $value % 28

            $result += $initial[$initialIndex]
            $result += $vowel[$vowelIndex]
            $result += $final[$finalIndex]
        }
        elseif ([char]::IsDigit($character)) {
            $result += [string]$character
        }
        elseif ($character -eq "," -or $character -eq "·") {
            $result += "-"
        }
    }

    $result = $result -replace '(?<=[a-z])(?=\d)', '-'
    $result = $result -replace '-+', '-'
    $result = $result.Trim("-")

    return "$result-dong"
}

$districtPattern = [regex]::new(
    '(?is)(?<number>\d{1,2})\)\s*(?<name>[가-힣]+구).*?<table[^>]*>(?<table>.*?)</table>'
)

$rowPattern = [regex]::new(
    '(?is)<tr[^>]*>\s*<td[^>]*>(?<admin>.*?)</td>\s*<td[^>]*>'
)

$regions = @()

foreach ($districtMatch in $districtPattern.Matches($html)) {
    $districtName = $districtMatch.Groups["name"].Value.Trim()

    if (-not $districtSlugs.Contains($districtName)) {
        continue
    }

    if ($completedDistricts -contains $districtName) {
        continue
    }

    $districtSlug = $districtSlugs[$districtName]
    $districtEnglish = ($districtSlug -replace '-gu$', '').ToUpper()
    $tableHtml = $districtMatch.Groups["table"].Value

    $dongs = @()
    $usedSlugs = @{}

    foreach ($rowMatch in $rowPattern.Matches($tableHtml)) {
        $adminHtml = $rowMatch.Groups["admin"].Value

        $adminName = [regex]::Replace(
            $adminHtml,
            '<[^>]+>',
            ''
        )

        $adminName = [System.Web.HttpUtility]::HtmlDecode($adminName)
        $adminName = $adminName -replace '\s+', ''
        $adminName = $adminName -replace '\([^)]*\)', ''
        $adminName = $adminName.Trim()

        if ($adminName -notmatch '동$') {
            continue
        }

        $slug = Convert-ToDongSlug -Name $adminName
        $originalSlug = $slug
        $duplicateNumber = 2

        while ($usedSlugs.ContainsKey($slug)) {
            $slug = "$originalSlug-$duplicateNumber"
            $duplicateNumber++
        }

        $usedSlugs[$slug] = $true

        $dongs += [ordered]@{
            slug = $slug
            name = $adminName
        }
    }

    $regions += [ordered]@{
        slug    = $districtSlug
        name    = $districtName
        english = $districtEnglish
        dongs   = $dongs
    }

    Write-Host "$districtName 추출 완료: $($dongs.Count)개 동"
}

if (-not ($regions | Where-Object { $_.name -eq "서대문구" })) {
    $regions += [ordered]@{
        slug    = "seodaemun-gu"
        name    = "서대문구"
        english = "SEODAEMUN"
        dongs   = @(
            [ordered]@{ slug = "chunghyeon-dong";  name = "충현동" }
            [ordered]@{ slug = "cheonyeon-dong";   name = "천연동" }
            [ordered]@{ slug = "bukahyeon-dong";   name = "북아현동" }
            [ordered]@{ slug = "sinchon-dong";     name = "신촌동" }
            [ordered]@{ slug = "yeonhui-dong";     name = "연희동" }
            [ordered]@{ slug = "hongje-1-dong";    name = "홍제1동" }
            [ordered]@{ slug = "hongje-2-dong";    name = "홍제2동" }
            [ordered]@{ slug = "hongje-3-dong";    name = "홍제3동" }
            [ordered]@{ slug = "hongeun-1-dong";   name = "홍은1동" }
            [ordered]@{ slug = "hongeun-2-dong";   name = "홍은2동" }
            [ordered]@{ slug = "namgajwa-1-dong";  name = "남가좌1동" }
            [ordered]@{ slug = "namgajwa-2-dong";  name = "남가좌2동" }
            [ordered]@{ slug = "bukgajwa-1-dong";  name = "북가좌1동" }
            [ordered]@{ slug = "bukgajwa-2-dong";  name = "북가좌2동" }
        )
    }

    Write-Host "서대문구 보완 완료: 14개 동"
}

if (-not ($regions | Where-Object { $sourcePath = Join-Path $PSScriptRoot "seoul-official.html"
$outputPath = Join-Path $PSScriptRoot "seoul-regions.json"

if (-not (Test-Path -LiteralPath $sourcePath)) {
    Write-Host "오류: 서울시 공식 자료 파일을 찾을 수 없습니다."
    exit 1
}

Add-Type -AssemblyName System.Web

$html = Get-Content `
    -LiteralPath $sourcePath `
    -Raw `
    -Encoding UTF8

$districtSlugs = [ordered]@{
    "강남구"     = "gangnam-gu"
    "강동구"     = "gangdong-gu"
    "강북구"     = "gangbuk-gu"
    "강서구"     = "gangseo-gu"
    "관악구"     = "gwanak-gu"
    "광진구"     = "gwangjin-gu"
    "구로구"     = "guro-gu"
    "금천구"     = "geumcheon-gu"
    "노원구"     = "nowon-gu"
    "도봉구"     = "dobong-gu"
    "동대문구"   = "dongdaemun-gu"
    "동작구"     = "dongjak-gu"
    "마포구"     = "mapo-gu"
    "서대문구"   = "seodaemun-gu"
    "서초구"     = "seocho-gu"
    "성동구"     = "seongdong-gu"
    "성북구"     = "seongbuk-gu"
    "송파구"     = "songpa-gu"
    "양천구"     = "yangcheon-gu"
    "영등포구"   = "yeongdeungpo-gu"
    "용산구"     = "yongsan-gu"
    "은평구"     = "eunpyeong-gu"
    "종로구"     = "jongno-gu"
    "중구"       = "jung-gu"
    "중랑구"     = "jungnang-gu"
}

$completedDistricts = @(
    "강남구",
    "강동구",
    "강북구",
    "강서구"
)

function Convert-ToDongSlug {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $initial = @(
        "g","kk","n","d","tt","r","m","b","pp",
        "s","ss","","j","jj","ch","k","t","p","h"
    )

    $vowel = @(
        "a","ae","ya","yae","eo","e","yeo","ye",
        "o","wa","wae","oe","yo","u","wo","we",
        "wi","yu","eu","ui","i"
    )

    $final = @(
        "","k","k","k","n","n","n","t","l","k",
        "m","l","l","l","p","l","m","p","p","t",
        "t","ng","t","t","k","t","p","h"
    )

    $baseName = $Name

    if ($baseName.EndsWith("동")) {
        $baseName = $baseName.Substring(0, $baseName.Length - 1)
    }

    $result = ""

    foreach ($character in $baseName.ToCharArray()) {
        $code = [int][char]$character

        if ($code -ge 0xAC00 -and $code -le 0xD7A3) {
            $value = $code - 0xAC00

            $initialIndex = [int]($value / 588)
            $vowelIndex = [int](($value % 588) / 28)
            $finalIndex = $value % 28

            $result += $initial[$initialIndex]
            $result += $vowel[$vowelIndex]
            $result += $final[$finalIndex]
        }
        elseif ([char]::IsDigit($character)) {
            $result += [string]$character
        }
        elseif ($character -eq "," -or $character -eq "·") {
            $result += "-"
        }
    }

    $result = $result -replace '(?<=[a-z])(?=\d)', '-'
    $result = $result -replace '-+', '-'
    $result = $result.Trim("-")

    return "$result-dong"
}

$districtPattern = [regex]::new(
    '(?is)(?<number>\d{1,2})\)\s*(?<name>[가-힣]+구).*?<table[^>]*>(?<table>.*?)</table>'
)

$rowPattern = [regex]::new(
    '(?is)<tr[^>]*>\s*<td[^>]*>(?<admin>.*?)</td>\s*<td[^>]*>'
)

$regions = @()

foreach ($districtMatch in $districtPattern.Matches($html)) {
    $districtName = $districtMatch.Groups["name"].Value.Trim()

    if (-not $districtSlugs.Contains($districtName)) {
        continue
    }

    if ($completedDistricts -contains $districtName) {
        continue
    }

    $districtSlug = $districtSlugs[$districtName]
    $districtEnglish = ($districtSlug -replace '-gu$', '').ToUpper()
    $tableHtml = $districtMatch.Groups["table"].Value

    $dongs = @()
    $usedSlugs = @{}

    foreach ($rowMatch in $rowPattern.Matches($tableHtml)) {
        $adminHtml = $rowMatch.Groups["admin"].Value

        $adminName = [regex]::Replace(
            $adminHtml,
            '<[^>]+>',
            ''
        )

        $adminName = [System.Web.HttpUtility]::HtmlDecode($adminName)
        $adminName = $adminName -replace '\s+', ''
        $adminName = $adminName -replace '\([^)]*\)', ''
        $adminName = $adminName.Trim()

        if ($adminName -notmatch '동$') {
            continue
        }

        $slug = Convert-ToDongSlug -Name $adminName
        $originalSlug = $slug
        $duplicateNumber = 2

        while ($usedSlugs.ContainsKey($slug)) {
            $slug = "$originalSlug-$duplicateNumber"
            $duplicateNumber++
        }

        $usedSlugs[$slug] = $true

        $dongs += [ordered]@{
            slug = $slug
            name = $adminName
        }
    }

    $regions += [ordered]@{
        slug    = $districtSlug
        name    = $districtName
        english = $districtEnglish
        dongs   = $dongs
    }

    Write-Host "$districtName 추출 완료: $($dongs.Count)개 동"
}

if (-not ($regions | Where-Object { $_.name -eq "서대문구" })) {
    $regions += [ordered]@{
        slug    = "seodaemun-gu"
        name    = "서대문구"
        english = "SEODAEMUN"
        dongs   = @(
            [ordered]@{ slug = "chunghyeon-dong";  name = "충현동" }
            [ordered]@{ slug = "cheonyeon-dong";   name = "천연동" }
            [ordered]@{ slug = "bukahyeon-dong";   name = "북아현동" }
            [ordered]@{ slug = "sinchon-dong";     name = "신촌동" }
            [ordered]@{ slug = "yeonhui-dong";     name = "연희동" }
            [ordered]@{ slug = "hongje-1-dong";    name = "홍제1동" }
            [ordered]@{ slug = "hongje-2-dong";    name = "홍제2동" }
            [ordered]@{ slug = "hongje-3-dong";    name = "홍제3동" }
            [ordered]@{ slug = "hongeun-1-dong";   name = "홍은1동" }
            [ordered]@{ slug = "hongeun-2-dong";   name = "홍은2동" }
            [ordered]@{ slug = "namgajwa-1-dong";  name = "남가좌1동" }
            [ordered]@{ slug = "namgajwa-2-dong";  name = "남가좌2동" }
            [ordered]@{ slug = "bukgajwa-1-dong";  name = "북가좌1동" }
            [ordered]@{ slug = "bukgajwa-2-dong";  name = "북가좌2동" }
        )
    }

    Write-Host "서대문구 보완 완료: 14개 동"
}

$totalDongs = (
    $regions |
    ForEach-Object { $_.dongs.Count } |
    Measure-Object -Sum
).Sum

if ($regions.Count -ne 21) {
    Write-Host "오류: 추출된 구 개수가 21개가 아닙니다."
    Write-Host "현재 구 개수: $($regions.Count)"
    exit 1
}

if ($totalDongs -ne 353) {
    Write-Host "오류: 추출된 동 개수가 예상과 다릅니다."
    Write-Host "현재 동 개수: $totalDongs"
    exit 1
}

$json = $regions | ConvertTo-Json -Depth 8

[System.IO.File]::WriteAllText(
    $outputPath,
    $json,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "--------------------------------"
Write-Host "서울 나머지 구 데이터 작성 완료"
Write-Host "구 개수: $($regions.Count)"
Write-Host "동 개수: $totalDongs".name -eq "서대문구" })) {
    $regions += [pscustomobject]@{
        slug    = "seodaemun-gu"
        name    = "서대문구"
        english = "SEODAEMUN"
        dongs   = @(
            [pscustomobject]@{ slug = "chunghyeon-dong"; name = "충현동" }
            [pscustomobject]@{ slug = "cheonyeon-dong"; name = "천연동" }
            [pscustomobject]@{ slug = "bukahyeon-dong"; name = "북아현동" }
            [pscustomobject]@{ slug = "sinchon-dong"; name = "신촌동" }
            [pscustomobject]@{ slug = "yeonhui-dong"; name = "연희동" }
            [pscustomobject]@{ slug = "hongje-1-dong"; name = "홍제1동" }
            [pscustomobject]@{ slug = "hongje-2-dong"; name = "홍제2동" }
            [pscustomobject]@{ slug = "hongje-3-dong"; name = "홍제3동" }
            [pscustomobject]@{ slug = "hongeun-1-dong"; name = "홍은1동" }
            [pscustomobject]@{ slug = "hongeun-2-dong"; name = "홍은2동" }
            [pscustomobject]@{ slug = "namgajwa-1-dong"; name = "남가좌1동" }
            [pscustomobject]@{ slug = "namgajwa-2-dong"; name = "남가좌2동" }
            [pscustomobject]@{ slug = "bukgajwa-1-dong"; name = "북가좌1동" }
            [pscustomobject]@{ slug = "bukgajwa-2-dong"; name = "북가좌2동" }
        )
    }

    Write-Host "서대문구 보완 완료: 14개 동"
}

$totalDongs = (
    $regions |
    ForEach-Object { $_.dongs.Count } |
    Measure-Object -Sum
).Sum

if ($regions.Count -ne 21) {
    Write-Host "오류: 추출된 구 개수가 21개가 아닙니다."
    Write-Host "현재 구 개수: $($regions.Count)"
    exit 1
}

if ($totalDongs -ne 353) {
    Write-Host "오류: 추출된 동 개수가 예상과 다릅니다."
    Write-Host "현재 동 개수: $totalDongs"
    exit 1
}

$json = $regions | ConvertTo-Json -Depth 8

[System.IO.File]::WriteAllText(
    $outputPath,
    $json,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "--------------------------------"
Write-Host "서울 나머지 구 데이터 작성 완료"
Write-Host "구 개수: $($regions.Count)"
Write-Host "동 개수: $totalDongs".name -eq "서대문구" })) {
    $regions += [pscustomobject]@{
        slug    = "seodaemun-gu"
        name    = "서대문구"
        english = "SEODAEMUN"
        dongs   = @(
            [pscustomobject]@{ slug = "chunghyeon-dong"; name = "충현동" }
            [pscustomobject]@{ slug = "cheonyeon-dong"; name = "천연동" }
            [pscustomobject]@{ slug = "bukahyeon-dong"; name = "북아현동" }
            [pscustomobject]@{ slug = "sinchon-dong"; name = "신촌동" }
            [pscustomobject]@{ slug = "yeonhui-dong"; name = "연희동" }
            [pscustomobject]@{ slug = "hongje-1-dong"; name = "홍제1동" }
            [pscustomobject]@{ slug = "hongje-2-dong"; name = "홍제2동" }
            [pscustomobject]@{ slug = "hongje-3-dong"; name = "홍제3동" }
            [pscustomobject]@{ slug = "hongeun-1-dong"; name = "홍은1동" }
            [pscustomobject]@{ slug = "hongeun-2-dong"; name = "홍은2동" }
            [pscustomobject]@{ slug = "namgajwa-1-dong"; name = "남가좌1동" }
            [pscustomobject]@{ slug = "namgajwa-2-dong"; name = "남가좌2동" }
            [pscustomobject]@{ slug = "bukgajwa-1-dong"; name = "북가좌1동" }
            [pscustomobject]@{ slug = "bukgajwa-2-dong"; name = "북가좌2동" }
        )
    }

    Write-Host "서대문구 보완 완료: 14개 동"
}

$totalDongs = (
    $regions |
    ForEach-Object { $_.dongs.Count } |
    Measure-Object -Sum
).Sum

if ($regions.Count -ne 21) {
    Write-Host "오류: 추출된 구 개수가 21개가 아닙니다."
    Write-Host "현재 구 개수: $($regions.Count)"
    exit 1
}

if ($totalDongs -ne 353) {
    Write-Host "오류: 추출된 동 개수가 예상과 다릅니다."
    Write-Host "현재 동 개수: $totalDongs"
    exit 1
}

$json = $regions | ConvertTo-Json -Depth 8

[System.IO.File]::WriteAllText(
    $outputPath,
    $json,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "--------------------------------"
Write-Host "서울 나머지 구 데이터 작성 완료"
Write-Host "구 개수: $($regions.Count)"
Write-Host "동 개수: $totalDongs".name -eq "서대문구" })) {
    $regions += [pscustomobject]@{
        slug    = "seodaemun-gu"
        name    = "서대문구"
        english = "SEODAEMUN"
        dongs   = @(
            [pscustomobject]@{ slug = "chunghyeon-dong"; name = "충현동" }
            [pscustomobject]@{ slug = "cheonyeon-dong"; name = "천연동" }
            [pscustomobject]@{ slug = "bukahyeon-dong"; name = "북아현동" }
            [pscustomobject]@{ slug = "sinchon-dong"; name = "신촌동" }
            [pscustomobject]@{ slug = "yeonhui-dong"; name = "연희동" }
            [pscustomobject]@{ slug = "hongje-1-dong"; name = "홍제1동" }
            [pscustomobject]@{ slug = "hongje-2-dong"; name = "홍제2동" }
            [pscustomobject]@{ slug = "hongje-3-dong"; name = "홍제3동" }
            [pscustomobject]@{ slug = "hongeun-1-dong"; name = "홍은1동" }
            [pscustomobject]@{ slug = "hongeun-2-dong"; name = "홍은2동" }
            [pscustomobject]@{ slug = "namgajwa-1-dong"; name = "남가좌1동" }
            [pscustomobject]@{ slug = "namgajwa-2-dong"; name = "남가좌2동" }
            [pscustomobject]@{ slug = "bukgajwa-1-dong"; name = "북가좌1동" }
            [pscustomobject]@{ slug = "bukgajwa-2-dong"; name = "북가좌2동" }
        )
    }

    Write-Host "서대문구 보완 완료: 14개 동"
}
# SEODAEMUN-FALLBACK
if (-not ($regions | Where-Object { $sourcePath = Join-Path $PSScriptRoot "seoul-official.html"
$outputPath = Join-Path $PSScriptRoot "seoul-regions.json"

if (-not (Test-Path -LiteralPath $sourcePath)) {
    Write-Host "오류: 서울시 공식 자료 파일을 찾을 수 없습니다."
    exit 1
}

Add-Type -AssemblyName System.Web

$html = Get-Content `
    -LiteralPath $sourcePath `
    -Raw `
    -Encoding UTF8

$districtSlugs = [ordered]@{
    "강남구"     = "gangnam-gu"
    "강동구"     = "gangdong-gu"
    "강북구"     = "gangbuk-gu"
    "강서구"     = "gangseo-gu"
    "관악구"     = "gwanak-gu"
    "광진구"     = "gwangjin-gu"
    "구로구"     = "guro-gu"
    "금천구"     = "geumcheon-gu"
    "노원구"     = "nowon-gu"
    "도봉구"     = "dobong-gu"
    "동대문구"   = "dongdaemun-gu"
    "동작구"     = "dongjak-gu"
    "마포구"     = "mapo-gu"
    "서대문구"   = "seodaemun-gu"
    "서초구"     = "seocho-gu"
    "성동구"     = "seongdong-gu"
    "성북구"     = "seongbuk-gu"
    "송파구"     = "songpa-gu"
    "양천구"     = "yangcheon-gu"
    "영등포구"   = "yeongdeungpo-gu"
    "용산구"     = "yongsan-gu"
    "은평구"     = "eunpyeong-gu"
    "종로구"     = "jongno-gu"
    "중구"       = "jung-gu"
    "중랑구"     = "jungnang-gu"
}

$completedDistricts = @(
    "강남구",
    "강동구",
    "강북구",
    "강서구"
)

function Convert-ToDongSlug {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $initial = @(
        "g","kk","n","d","tt","r","m","b","pp",
        "s","ss","","j","jj","ch","k","t","p","h"
    )

    $vowel = @(
        "a","ae","ya","yae","eo","e","yeo","ye",
        "o","wa","wae","oe","yo","u","wo","we",
        "wi","yu","eu","ui","i"
    )

    $final = @(
        "","k","k","k","n","n","n","t","l","k",
        "m","l","l","l","p","l","m","p","p","t",
        "t","ng","t","t","k","t","p","h"
    )

    $baseName = $Name

    if ($baseName.EndsWith("동")) {
        $baseName = $baseName.Substring(0, $baseName.Length - 1)
    }

    $result = ""

    foreach ($character in $baseName.ToCharArray()) {
        $code = [int][char]$character

        if ($code -ge 0xAC00 -and $code -le 0xD7A3) {
            $value = $code - 0xAC00

            $initialIndex = [int]($value / 588)
            $vowelIndex = [int](($value % 588) / 28)
            $finalIndex = $value % 28

            $result += $initial[$initialIndex]
            $result += $vowel[$vowelIndex]
            $result += $final[$finalIndex]
        }
        elseif ([char]::IsDigit($character)) {
            $result += [string]$character
        }
        elseif ($character -eq "," -or $character -eq "·") {
            $result += "-"
        }
    }

    $result = $result -replace '(?<=[a-z])(?=\d)', '-'
    $result = $result -replace '-+', '-'
    $result = $result.Trim("-")

    return "$result-dong"
}

$districtPattern = [regex]::new(
    '(?is)(?<number>\d{1,2})\)\s*(?<name>[가-힣]+구).*?<table[^>]*>(?<table>.*?)</table>'
)

$rowPattern = [regex]::new(
    '(?is)<tr[^>]*>\s*<td[^>]*>(?<admin>.*?)</td>\s*<td[^>]*>'
)

$regions = @()

foreach ($districtMatch in $districtPattern.Matches($html)) {
    $districtName = $districtMatch.Groups["name"].Value.Trim()

    if (-not $districtSlugs.Contains($districtName)) {
        continue
    }

    if ($completedDistricts -contains $districtName) {
        continue
    }

    $districtSlug = $districtSlugs[$districtName]
    $districtEnglish = ($districtSlug -replace '-gu$', '').ToUpper()
    $tableHtml = $districtMatch.Groups["table"].Value

    $dongs = @()
    $usedSlugs = @{}

    foreach ($rowMatch in $rowPattern.Matches($tableHtml)) {
        $adminHtml = $rowMatch.Groups["admin"].Value

        $adminName = [regex]::Replace(
            $adminHtml,
            '<[^>]+>',
            ''
        )

        $adminName = [System.Web.HttpUtility]::HtmlDecode($adminName)
        $adminName = $adminName -replace '\s+', ''
        $adminName = $adminName -replace '\([^)]*\)', ''
        $adminName = $adminName.Trim()

        if ($adminName -notmatch '동$') {
            continue
        }

        $slug = Convert-ToDongSlug -Name $adminName
        $originalSlug = $slug
        $duplicateNumber = 2

        while ($usedSlugs.ContainsKey($slug)) {
            $slug = "$originalSlug-$duplicateNumber"
            $duplicateNumber++
        }

        $usedSlugs[$slug] = $true

        $dongs += [ordered]@{
            slug = $slug
            name = $adminName
        }
    }

    $regions += [ordered]@{
        slug    = $districtSlug
        name    = $districtName
        english = $districtEnglish
        dongs   = $dongs
    }

    Write-Host "$districtName 추출 완료: $($dongs.Count)개 동"
}

if (-not ($regions | Where-Object { $_.name -eq "서대문구" })) {
    $regions += [ordered]@{
        slug    = "seodaemun-gu"
        name    = "서대문구"
        english = "SEODAEMUN"
        dongs   = @(
            [ordered]@{ slug = "chunghyeon-dong";  name = "충현동" }
            [ordered]@{ slug = "cheonyeon-dong";   name = "천연동" }
            [ordered]@{ slug = "bukahyeon-dong";   name = "북아현동" }
            [ordered]@{ slug = "sinchon-dong";     name = "신촌동" }
            [ordered]@{ slug = "yeonhui-dong";     name = "연희동" }
            [ordered]@{ slug = "hongje-1-dong";    name = "홍제1동" }
            [ordered]@{ slug = "hongje-2-dong";    name = "홍제2동" }
            [ordered]@{ slug = "hongje-3-dong";    name = "홍제3동" }
            [ordered]@{ slug = "hongeun-1-dong";   name = "홍은1동" }
            [ordered]@{ slug = "hongeun-2-dong";   name = "홍은2동" }
            [ordered]@{ slug = "namgajwa-1-dong";  name = "남가좌1동" }
            [ordered]@{ slug = "namgajwa-2-dong";  name = "남가좌2동" }
            [ordered]@{ slug = "bukgajwa-1-dong";  name = "북가좌1동" }
            [ordered]@{ slug = "bukgajwa-2-dong";  name = "북가좌2동" }
        )
    }

    Write-Host "서대문구 보완 완료: 14개 동"
}

if (-not ($regions | Where-Object { $sourcePath = Join-Path $PSScriptRoot "seoul-official.html"
$outputPath = Join-Path $PSScriptRoot "seoul-regions.json"

if (-not (Test-Path -LiteralPath $sourcePath)) {
    Write-Host "오류: 서울시 공식 자료 파일을 찾을 수 없습니다."
    exit 1
}

Add-Type -AssemblyName System.Web

$html = Get-Content `
    -LiteralPath $sourcePath `
    -Raw `
    -Encoding UTF8

$districtSlugs = [ordered]@{
    "강남구"     = "gangnam-gu"
    "강동구"     = "gangdong-gu"
    "강북구"     = "gangbuk-gu"
    "강서구"     = "gangseo-gu"
    "관악구"     = "gwanak-gu"
    "광진구"     = "gwangjin-gu"
    "구로구"     = "guro-gu"
    "금천구"     = "geumcheon-gu"
    "노원구"     = "nowon-gu"
    "도봉구"     = "dobong-gu"
    "동대문구"   = "dongdaemun-gu"
    "동작구"     = "dongjak-gu"
    "마포구"     = "mapo-gu"
    "서대문구"   = "seodaemun-gu"
    "서초구"     = "seocho-gu"
    "성동구"     = "seongdong-gu"
    "성북구"     = "seongbuk-gu"
    "송파구"     = "songpa-gu"
    "양천구"     = "yangcheon-gu"
    "영등포구"   = "yeongdeungpo-gu"
    "용산구"     = "yongsan-gu"
    "은평구"     = "eunpyeong-gu"
    "종로구"     = "jongno-gu"
    "중구"       = "jung-gu"
    "중랑구"     = "jungnang-gu"
}

$completedDistricts = @(
    "강남구",
    "강동구",
    "강북구",
    "강서구"
)

function Convert-ToDongSlug {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $initial = @(
        "g","kk","n","d","tt","r","m","b","pp",
        "s","ss","","j","jj","ch","k","t","p","h"
    )

    $vowel = @(
        "a","ae","ya","yae","eo","e","yeo","ye",
        "o","wa","wae","oe","yo","u","wo","we",
        "wi","yu","eu","ui","i"
    )

    $final = @(
        "","k","k","k","n","n","n","t","l","k",
        "m","l","l","l","p","l","m","p","p","t",
        "t","ng","t","t","k","t","p","h"
    )

    $baseName = $Name

    if ($baseName.EndsWith("동")) {
        $baseName = $baseName.Substring(0, $baseName.Length - 1)
    }

    $result = ""

    foreach ($character in $baseName.ToCharArray()) {
        $code = [int][char]$character

        if ($code -ge 0xAC00 -and $code -le 0xD7A3) {
            $value = $code - 0xAC00

            $initialIndex = [int]($value / 588)
            $vowelIndex = [int](($value % 588) / 28)
            $finalIndex = $value % 28

            $result += $initial[$initialIndex]
            $result += $vowel[$vowelIndex]
            $result += $final[$finalIndex]
        }
        elseif ([char]::IsDigit($character)) {
            $result += [string]$character
        }
        elseif ($character -eq "," -or $character -eq "·") {
            $result += "-"
        }
    }

    $result = $result -replace '(?<=[a-z])(?=\d)', '-'
    $result = $result -replace '-+', '-'
    $result = $result.Trim("-")

    return "$result-dong"
}

$districtPattern = [regex]::new(
    '(?is)(?<number>\d{1,2})\)\s*(?<name>[가-힣]+구).*?<table[^>]*>(?<table>.*?)</table>'
)

$rowPattern = [regex]::new(
    '(?is)<tr[^>]*>\s*<td[^>]*>(?<admin>.*?)</td>\s*<td[^>]*>'
)

$regions = @()

foreach ($districtMatch in $districtPattern.Matches($html)) {
    $districtName = $districtMatch.Groups["name"].Value.Trim()

    if (-not $districtSlugs.Contains($districtName)) {
        continue
    }

    if ($completedDistricts -contains $districtName) {
        continue
    }

    $districtSlug = $districtSlugs[$districtName]
    $districtEnglish = ($districtSlug -replace '-gu$', '').ToUpper()
    $tableHtml = $districtMatch.Groups["table"].Value

    $dongs = @()
    $usedSlugs = @{}

    foreach ($rowMatch in $rowPattern.Matches($tableHtml)) {
        $adminHtml = $rowMatch.Groups["admin"].Value

        $adminName = [regex]::Replace(
            $adminHtml,
            '<[^>]+>',
            ''
        )

        $adminName = [System.Web.HttpUtility]::HtmlDecode($adminName)
        $adminName = $adminName -replace '\s+', ''
        $adminName = $adminName -replace '\([^)]*\)', ''
        $adminName = $adminName.Trim()

        if ($adminName -notmatch '동$') {
            continue
        }

        $slug = Convert-ToDongSlug -Name $adminName
        $originalSlug = $slug
        $duplicateNumber = 2

        while ($usedSlugs.ContainsKey($slug)) {
            $slug = "$originalSlug-$duplicateNumber"
            $duplicateNumber++
        }

        $usedSlugs[$slug] = $true

        $dongs += [ordered]@{
            slug = $slug
            name = $adminName
        }
    }

    $regions += [ordered]@{
        slug    = $districtSlug
        name    = $districtName
        english = $districtEnglish
        dongs   = $dongs
    }

    Write-Host "$districtName 추출 완료: $($dongs.Count)개 동"
}

if (-not ($regions | Where-Object { $_.name -eq "서대문구" })) {
    $regions += [ordered]@{
        slug    = "seodaemun-gu"
        name    = "서대문구"
        english = "SEODAEMUN"
        dongs   = @(
            [ordered]@{ slug = "chunghyeon-dong";  name = "충현동" }
            [ordered]@{ slug = "cheonyeon-dong";   name = "천연동" }
            [ordered]@{ slug = "bukahyeon-dong";   name = "북아현동" }
            [ordered]@{ slug = "sinchon-dong";     name = "신촌동" }
            [ordered]@{ slug = "yeonhui-dong";     name = "연희동" }
            [ordered]@{ slug = "hongje-1-dong";    name = "홍제1동" }
            [ordered]@{ slug = "hongje-2-dong";    name = "홍제2동" }
            [ordered]@{ slug = "hongje-3-dong";    name = "홍제3동" }
            [ordered]@{ slug = "hongeun-1-dong";   name = "홍은1동" }
            [ordered]@{ slug = "hongeun-2-dong";   name = "홍은2동" }
            [ordered]@{ slug = "namgajwa-1-dong";  name = "남가좌1동" }
            [ordered]@{ slug = "namgajwa-2-dong";  name = "남가좌2동" }
            [ordered]@{ slug = "bukgajwa-1-dong";  name = "북가좌1동" }
            [ordered]@{ slug = "bukgajwa-2-dong";  name = "북가좌2동" }
        )
    }

    Write-Host "서대문구 보완 완료: 14개 동"
}

$totalDongs = (
    $regions |
    ForEach-Object { $_.dongs.Count } |
    Measure-Object -Sum
).Sum

if ($regions.Count -ne 21) {
    Write-Host "오류: 추출된 구 개수가 21개가 아닙니다."
    Write-Host "현재 구 개수: $($regions.Count)"
    exit 1
}

if ($totalDongs -ne 353) {
    Write-Host "오류: 추출된 동 개수가 예상과 다릅니다."
    Write-Host "현재 동 개수: $totalDongs"
    exit 1
}

$json = $regions | ConvertTo-Json -Depth 8

[System.IO.File]::WriteAllText(
    $outputPath,
    $json,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "--------------------------------"
Write-Host "서울 나머지 구 데이터 작성 완료"
Write-Host "구 개수: $($regions.Count)"
Write-Host "동 개수: $totalDongs".name -eq "서대문구" })) {
    $regions += [pscustomobject]@{
        slug    = "seodaemun-gu"
        name    = "서대문구"
        english = "SEODAEMUN"
        dongs   = @(
            [pscustomobject]@{ slug = "chunghyeon-dong"; name = "충현동" }
            [pscustomobject]@{ slug = "cheonyeon-dong"; name = "천연동" }
            [pscustomobject]@{ slug = "bukahyeon-dong"; name = "북아현동" }
            [pscustomobject]@{ slug = "sinchon-dong"; name = "신촌동" }
            [pscustomobject]@{ slug = "yeonhui-dong"; name = "연희동" }
            [pscustomobject]@{ slug = "hongje-1-dong"; name = "홍제1동" }
            [pscustomobject]@{ slug = "hongje-2-dong"; name = "홍제2동" }
            [pscustomobject]@{ slug = "hongje-3-dong"; name = "홍제3동" }
            [pscustomobject]@{ slug = "hongeun-1-dong"; name = "홍은1동" }
            [pscustomobject]@{ slug = "hongeun-2-dong"; name = "홍은2동" }
            [pscustomobject]@{ slug = "namgajwa-1-dong"; name = "남가좌1동" }
            [pscustomobject]@{ slug = "namgajwa-2-dong"; name = "남가좌2동" }
            [pscustomobject]@{ slug = "bukgajwa-1-dong"; name = "북가좌1동" }
            [pscustomobject]@{ slug = "bukgajwa-2-dong"; name = "북가좌2동" }
        )
    }

    Write-Host "서대문구 보완 완료: 14개 동"
}

$totalDongs = (
    $regions |
    ForEach-Object { $_.dongs.Count } |
    Measure-Object -Sum
).Sum

if ($regions.Count -ne 21) {
    Write-Host "오류: 추출된 구 개수가 21개가 아닙니다."
    Write-Host "현재 구 개수: $($regions.Count)"
    exit 1
}

if ($totalDongs -ne 353) {
    Write-Host "오류: 추출된 동 개수가 예상과 다릅니다."
    Write-Host "현재 동 개수: $totalDongs"
    exit 1
}

$json = $regions | ConvertTo-Json -Depth 8

[System.IO.File]::WriteAllText(
    $outputPath,
    $json,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "--------------------------------"
Write-Host "서울 나머지 구 데이터 작성 완료"
Write-Host "구 개수: $($regions.Count)"
Write-Host "동 개수: $totalDongs".name -eq "서대문구" })) {
    $regions += [pscustomobject]@{
        slug    = "seodaemun-gu"
        name    = "서대문구"
        english = "SEODAEMUN"
        dongs   = @(
            [pscustomobject]@{ slug = "chunghyeon-dong"; name = "충현동" }
            [pscustomobject]@{ slug = "cheonyeon-dong"; name = "천연동" }
            [pscustomobject]@{ slug = "bukahyeon-dong"; name = "북아현동" }
            [pscustomobject]@{ slug = "sinchon-dong"; name = "신촌동" }
            [pscustomobject]@{ slug = "yeonhui-dong"; name = "연희동" }
            [pscustomobject]@{ slug = "hongje-1-dong"; name = "홍제1동" }
            [pscustomobject]@{ slug = "hongje-2-dong"; name = "홍제2동" }
            [pscustomobject]@{ slug = "hongje-3-dong"; name = "홍제3동" }
            [pscustomobject]@{ slug = "hongeun-1-dong"; name = "홍은1동" }
            [pscustomobject]@{ slug = "hongeun-2-dong"; name = "홍은2동" }
            [pscustomobject]@{ slug = "namgajwa-1-dong"; name = "남가좌1동" }
            [pscustomobject]@{ slug = "namgajwa-2-dong"; name = "남가좌2동" }
            [pscustomobject]@{ slug = "bukgajwa-1-dong"; name = "북가좌1동" }
            [pscustomobject]@{ slug = "bukgajwa-2-dong"; name = "북가좌2동" }
        )
    }

    Write-Host "서대문구 보완 완료: 14개 동"
}

$totalDongs = (
    $regions |
    ForEach-Object { $_.dongs.Count } |
    Measure-Object -Sum
).Sum

if ($regions.Count -ne 21) {
    Write-Host "오류: 추출된 구 개수가 21개가 아닙니다."
    Write-Host "현재 구 개수: $($regions.Count)"
    exit 1
}

if ($totalDongs -ne 353) {
    Write-Host "오류: 추출된 동 개수가 예상과 다릅니다."
    Write-Host "현재 동 개수: $totalDongs"
    exit 1
}

$json = $regions | ConvertTo-Json -Depth 8

[System.IO.File]::WriteAllText(
    $outputPath,
    $json,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "--------------------------------"
Write-Host "서울 나머지 구 데이터 작성 완료"
Write-Host "구 개수: $($regions.Count)"
Write-Host "동 개수: $totalDongs"
