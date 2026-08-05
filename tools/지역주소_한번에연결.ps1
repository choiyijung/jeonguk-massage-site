# 지역별 인기업체 주소 한 번에 연결
# index.html이 있는 사이트 최상위 폴더에서 실행하세요.

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$items = @(
    [PSCustomObject]@{ Folder = '서울'; Url = 'https://www.gunmachonsa.shop/seoul' },
    [PSCustomObject]@{ Folder = '강남구'; Url = 'https://www.gunmachonsa.shop/Gangnamgu' },
    [PSCustomObject]@{ Folder = '송파구'; Url = 'https://www.gunmachonsa.shop/songpagu' },
    [PSCustomObject]@{ Folder = '강북구'; Url = 'https://www.gunmachonsa.shop/Gangbukgu' },
    [PSCustomObject]@{ Folder = '강서구'; Url = 'https://www.gunmachonsa.shop/Gangseogu' },
    [PSCustomObject]@{ Folder = '영등포구'; Url = 'https://www.gunmachonsa.shop/Yeongdeungpogu' },
    [PSCustomObject]@{ Folder = '마포구'; Url = 'https://www.gunmachonsa.shop/Mapogu' },
    [PSCustomObject]@{ Folder = '성북구'; Url = 'https://www.gunmachonsa.shop/Seongbukgu' },
    [PSCustomObject]@{ Folder = '관악구'; Url = 'https://www.gunmachonsa.shop/Gwanakgu' },
    [PSCustomObject]@{ Folder = '금천구'; Url = 'https://www.gunmachonsa.shop/Geumcheongu' },
    [PSCustomObject]@{ Folder = '종로구'; Url = 'https://www.gunmachonsa.shop/Jongnogu' },
    [PSCustomObject]@{ Folder = '은평구'; Url = 'https://www.gunmachonsa.shop/Eunpyeonggu' },
    [PSCustomObject]@{ Folder = '서대문구'; Url = 'https://www.gunmachonsa.shop/Seodaemungu' },
    [PSCustomObject]@{ Folder = '용산구'; Url = 'https://www.gunmachonsa.shop/yongsangu' },
    [PSCustomObject]@{ Folder = '도봉구'; Url = 'https://www.gunmachonsa.shop/Dobonggu' },
    [PSCustomObject]@{ Folder = '구로구'; Url = 'https://www.gunmachonsa.shop/Gurogu' },
    [PSCustomObject]@{ Folder = '동작구'; Url = 'https://www.gunmachonsa.shop/Dongjakgu' },
    [PSCustomObject]@{ Folder = '동대문구'; Url = 'https://www.gunmachonsa.shop/Dongdaemungu' },
    [PSCustomObject]@{ Folder = '중구'; Url = 'https://www.gunmachonsa.shop/Junggu' },
    [PSCustomObject]@{ Folder = '성동구'; Url = 'https://www.gunmachonsa.shop/Seongdonggu' },
    [PSCustomObject]@{ Folder = '광진구'; Url = 'https://www.gunmachonsa.shop/Gwangjingu' },
    [PSCustomObject]@{ Folder = '중랑구'; Url = 'https://www.gunmachonsa.shop/Jungnanggu' },
    [PSCustomObject]@{ Folder = '노원구'; Url = 'https://www.gunmachonsa.shop/Nowongu' },
    [PSCustomObject]@{ Folder = '양천구'; Url = 'https://www.gunmachonsa.shop/Yangcheongu' },
    [PSCustomObject]@{ Folder = '서초구'; Url = 'https://www.gunmachonsa.shop/Seochogu' },
    [PSCustomObject]@{ Folder = '강동구'; Url = 'https://www.gunmachonsa.shop/Gangdonggu' },
    [PSCustomObject]@{ Folder = '인천'; Url = 'https://www.gunmachonsa.shop/incheon' },
    [PSCustomObject]@{ Folder = '미추홀구'; Url = 'https://www.gunmachonsa.shop/Michuholgu' },
    [PSCustomObject]@{ Folder = '연수구'; Url = 'https://www.gunmachonsa.shop/Yeonsugu' },
    [PSCustomObject]@{ Folder = '남동구'; Url = 'https://www.gunmachonsa.shop/Namdonggu' },
    [PSCustomObject]@{ Folder = '부평구'; Url = 'https://www.gunmachonsa.shop/Bupyeonggu' },
    [PSCustomObject]@{ Folder = '계양구'; Url = 'https://www.gunmachonsa.shop/Gyeyanggu' },
    [PSCustomObject]@{ Folder = '서구'; Url = 'https://www.gunmachonsa.shop/IncheonSeo-gu' },
    [PSCustomObject]@{ Folder = '안산시'; Url = 'https://www.gunmachonsa.shop/Ansan' },
    [PSCustomObject]@{ Folder = '안산상록구'; Url = 'https://www.gunmachonsa.shop/Sangnokgu' },
    [PSCustomObject]@{ Folder = '안산단원구'; Url = 'https://www.gunmachonsa.shop/Danwongu' },
    [PSCustomObject]@{ Folder = '수원시'; Url = 'https://www.gunmachonsa.shop/Suwon' },
    [PSCustomObject]@{ Folder = '수원권선구'; Url = 'https://www.gunmachonsa.shop/Gwonseongu' },
    [PSCustomObject]@{ Folder = '수원장안구'; Url = 'https://www.gunmachonsa.shop/Jangangu' },
    [PSCustomObject]@{ Folder = '수원팔달구'; Url = 'https://www.gunmachonsa.shop/Paldalgu' },
    [PSCustomObject]@{ Folder = '수원영통구'; Url = 'https://www.gunmachonsa.shop/Yeongtonggu' },
    [PSCustomObject]@{ Folder = '성남시'; Url = 'https://www.gunmachonsa.shop/Seongnam' },
    [PSCustomObject]@{ Folder = '성남수정구'; Url = 'https://www.gunmachonsa.shop/sujeonggu' },
    [PSCustomObject]@{ Folder = '성남중원구'; Url = 'https://www.gunmachonsa.shop/jungwongu' },
    [PSCustomObject]@{ Folder = '성남분당구'; Url = 'https://www.gunmachonsa.shop/Bundanggu' },
    [PSCustomObject]@{ Folder = '평택시'; Url = 'https://www.gunmachonsa.shop/Pyeongtaek' },
    [PSCustomObject]@{ Folder = '동두천시'; Url = 'https://www.gunmachonsa.shop/Dongducheonsi' },
    [PSCustomObject]@{ Folder = '과천시'; Url = 'https://www.gunmachonsa.shop/Gwacheonsi' },
    [PSCustomObject]@{ Folder = '구리시'; Url = 'https://www.gunmachonsa.shop/Gurisi' },
    [PSCustomObject]@{ Folder = '화성시'; Url = 'https://www.gunmachonsa.shop/Hwaseongsi' },
    [PSCustomObject]@{ Folder = '오산시'; Url = 'https://www.gunmachonsa.shop/Osansi' },
    [PSCustomObject]@{ Folder = '부천시'; Url = 'https://www.gunmachonsa.shop/Bucheonsi' },
    [PSCustomObject]@{ Folder = '부천원미구'; Url = 'https://www.gunmachonsa.shop/Wonmigu' },
    [PSCustomObject]@{ Folder = '부천소사구'; Url = 'https://www.gunmachonsa.shop/Sosagu' },
    [PSCustomObject]@{ Folder = '부천오정구'; Url = 'https://www.gunmachonsa.shop/Ojeonggu' },
    [PSCustomObject]@{ Folder = '시흥시'; Url = 'https://www.gunmachonsa.shop/Siheungsi' },
    [PSCustomObject]@{ Folder = '광명시'; Url = 'https://www.gunmachonsa.shop/Gwangmyeongsi' },
    [PSCustomObject]@{ Folder = '의정부시'; Url = 'https://www.gunmachonsa.shop/Uijeongbusi' },
    [PSCustomObject]@{ Folder = '김포시'; Url = 'https://www.gunmachonsa.shop/Gimposi' },
    [PSCustomObject]@{ Folder = '고양시'; Url = 'https://www.gunmachonsa.shop/Goyangsi' },
    [PSCustomObject]@{ Folder = '고양덕양구'; Url = 'https://www.gunmachonsa.shop/Deogyanggu' },
    [PSCustomObject]@{ Folder = '고양일산동구'; Url = 'https://www.gunmachonsa.shop/Ilsandonggu' },
    [PSCustomObject]@{ Folder = '고양일산서구'; Url = 'https://www.gunmachonsa.shop/IlsanSeogu' },
    [PSCustomObject]@{ Folder = '안양시'; Url = 'https://www.gunmachonsa.shop/Anyang' },
    [PSCustomObject]@{ Folder = '안양만안구'; Url = 'https://www.gunmachonsa.shop/Manangu' },
    [PSCustomObject]@{ Folder = '안양동안구'; Url = 'https://www.gunmachonsa.shop/Dongangu' },
    [PSCustomObject]@{ Folder = '군포시'; Url = 'https://www.gunmachonsa.shop/Gunposi' },
    [PSCustomObject]@{ Folder = '의왕시'; Url = 'https://www.gunmachonsa.shop/Uiwangsi' },
    [PSCustomObject]@{ Folder = '하남시'; Url = 'https://www.gunmachonsa.shop/Hanamsi' },
    [PSCustomObject]@{ Folder = '용인시'; Url = 'https://www.gunmachonsa.shop/Yonginsi' },
    [PSCustomObject]@{ Folder = '용인처인구'; Url = 'https://www.gunmachonsa.shop/Cheoingu' },
    [PSCustomObject]@{ Folder = '용인기흥구'; Url = 'https://www.gunmachonsa.shop/Giheunggu' },
    [PSCustomObject]@{ Folder = '용인수지구'; Url = 'https://www.gunmachonsa.shop/Sujigu' },
    [PSCustomObject]@{ Folder = '광주시'; Url = 'https://www.gunmachonsa.shop/GwangjuGyeonggi' },
    [PSCustomObject]@{ Folder = '남양주시'; Url = 'https://www.gunmachonsa.shop/Namyangjusi' },
    [PSCustomObject]@{ Folder = '파주시'; Url = 'https://www.gunmachonsa.shop/Pajusi' },
    [PSCustomObject]@{ Folder = '가평군'; Url = 'https://www.gunmachonsa.shop/Gapyeonggun' },
    [PSCustomObject]@{ Folder = '이천시'; Url = 'https://www.gunmachonsa.shop/Icheonsi' },
    [PSCustomObject]@{ Folder = '안성시'; Url = 'https://www.gunmachonsa.shop/Anseongsi' },
    [PSCustomObject]@{ Folder = '양주시'; Url = 'https://www.gunmachonsa.shop/Yangjusi' },
    [PSCustomObject]@{ Folder = '포천시'; Url = 'https://www.gunmachonsa.shop/Pocheonsi' },
    [PSCustomObject]@{ Folder = '여주시'; Url = 'https://www.gunmachonsa.shop/Yeojusi' },
    [PSCustomObject]@{ Folder = '양평군'; Url = 'https://www.gunmachonsa.shop/Yangpyeonggun' },
    [PSCustomObject]@{ Folder = '연천군'; Url = 'https://www.gunmachonsa.shop/Yeoncheongun' }
)

$success = 0
$missingPage = @()
$positionFail = @()

foreach ($item in $items) {
    $folder = $item.Folder
    $url = $item.Url
    $page = ".\$folder\index.html"

    if (-not (Test-Path $page)) {
        $missingPage += $folder
        Write-Host "$folder : 페이지 없음" -ForegroundColor Yellow
        continue
    }

    $html = Get-Content $page -Raw -Encoding UTF8

    # 전에 넣은 버튼 또는 작은 인기업체 보기 버튼 제거
    $html = [regex]::Replace(
        $html,
        '(?s)\s*<!-- POPULAR_LINK_START -->.*?<!-- POPULAR_LINK_END -->\s*',
        "`r`n"
    )

    $html = [regex]::Replace(
        $html,
        '(?s)<div[^>]*>\s*<a[^>]*>\s*인기업체 보기\s*</a>\s*</div>',
        ''
    )

    $html = [regex]::Replace(
        $html,
        '(?s)<a[^>]*>\s*인기업체 보기\s*</a>',
        ''
    )

    $html = [regex]::Replace(
        $html,
        '(?s)<div[^>]*>\s*<a[^>]*>\s*[^<]*인기업체 바로가기\s*</a>\s*</div>',
        ''
    )

    $button = @"
<!-- POPULAR_LINK_START -->
<div style="margin-top:26px;width:100%;">
  <a href="$url"
     target="_blank"
     rel="noopener noreferrer"
     style="display:flex;width:100%;min-height:54px;align-items:center;justify-content:center;border-radius:14px;background:#ffcf4a;color:#172033;font-weight:900;text-decoration:none;">
    $folder 인기업체 바로가기
  </a>
</div>
<!-- POPULAR_LINK_END -->
"@

    # 메인으로 이동 / 지역 전체 보기 버튼 줄 바로 위에 삽입
    $navPattern = '(?s)(<div[^>]*>\s*<a[^>]*>\s*메인으로 이동\s*</a>\s*<a[^>]*>\s*지역 전체 보기\s*</a>\s*</div>)'

    if ([regex]::IsMatch($html, $navPattern)) {
        $html = [regex]::Replace(
            $html,
            $navPattern,
            ($button + "`r`n`$1"),
            1
        )

        [System.IO.File]::WriteAllText(
            (Resolve-Path $page),
            $html,
            (New-Object System.Text.UTF8Encoding($false))
        )

        Write-Host "$folder 연결 완료" -ForegroundColor Green
        $success++
    }
    else {
        $positionFail += $folder
        Write-Host "$folder : 버튼 위치를 찾지 못함" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "지역별 인기업체 연결 작업 완료" -ForegroundColor Cyan
Write-Host "성공: $success 개"
Write-Host "페이지 없음: $($missingPage.Count) 개"
Write-Host "버튼 위치 못 찾음: $($positionFail.Count) 개"
Write-Host "======================================" -ForegroundColor Cyan

if ($missingPage.Count -gt 0) {
    Write-Host ""
    Write-Host "페이지가 없는 지역:" -ForegroundColor Yellow
    $missingPage | ForEach-Object { Write-Host "- $_" }
}

if ($positionFail.Count -gt 0) {
    Write-Host ""
    Write-Host "버튼 위치를 찾지 못한 지역:" -ForegroundColor Red
    $positionFail | ForEach-Object { Write-Host "- $_" }
}
