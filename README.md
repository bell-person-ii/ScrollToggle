# ScrollToggle

마우스를 연결하면 자연스러운 스크롤을 끄고, 빼면 다시 켜 주는 macOS 메뉴 막대 앱입니다.

macOS에서는 트랙패드와 마우스의 스크롤 방향이 설정 하나로 묶여 있습니다. 그래서 트랙패드는 자연스러운 스크롤로, 마우스 휠은 반대 방향으로 쓰고 싶으면 마우스를 꽂고 뺄 때마다 시스템 설정에 들어가야 합니다. ScrollToggle은 이 전환을 자동으로 해 줍니다.

## 기능

- **자동 전환**: 외장 마우스(USB/Bluetooth)가 연결되면 자연스러운 스크롤을 끄고, 트랙패드만 남으면 다시 켭니다. 앱을 켤 때와 장치를 꽂거나 뺄 때마다 적용됩니다.
- **수동 전환**: 메뉴 막대 아이콘을 클릭해 메뉴에서 직접 켜고 끌 수 있습니다. 직접 고른 값은 다음 장치 변경 전까지 유지됩니다.
- **상태 표시**: 켜져 있으면 `↕` 아이콘, 꺼져 있으면 흐린 `⇅` 아이콘이 표시됩니다. 방향이 바뀌면 메뉴, 마우스, 시스템 설정 중 무엇이 바꿨든 아이콘 아래에 2초 동안 말풍선으로 알려 줍니다.
- **즉시 반영**: 시스템 설정과 같은 내부 함수를 사용하므로 로그아웃하지 않아도 바로 적용됩니다.
- **로그인 시 실행**: 메뉴에서 켜면 로그인 항목으로 등록됩니다.
- Dock과 앱 전환기에 나타나지 않습니다. 입력 모니터링 같은 권한도 요구하지 않습니다.

## 요구 사항

- macOS 13 Ventura 이상 (Apple Silicon, Intel 모두 지원)
- Xcode 또는 Xcode Command Line Tools

Command Line Tools가 없다면 먼저 설치하세요.

```sh
xcode-select --install
```

## 설치

미리 빌드된 앱은 배포하지 않습니다. 소스를 받아 직접 빌드해 주세요.

```sh
git clone https://github.com/bell-person-ii/ScrollToggle.git
cd ScrollToggle
./build.sh
```

`build/ScrollToggle.app`이 만들어집니다. `/Applications`로 옮긴 뒤 실행하면 메뉴 막대에 아이콘이 나타납니다.

```sh
cp -R build/ScrollToggle.app /Applications/
open /Applications/ScrollToggle.app
```

빌드한 앱은 ad-hoc 서명만 되어 있습니다. 빌드한 Mac에서는 바로 실행되지만, 다른 Mac에 복사하면 Gatekeeper가 실행을 막을 수 있습니다. 쓰려는 Mac마다 따로 빌드하세요.

### 업데이트

앱을 종료한 뒤 최신 소스를 받아 다시 빌드하고 덮어씁니다.

```sh
git pull
./build.sh
rm -rf /Applications/ScrollToggle.app
cp -R build/ScrollToggle.app /Applications/
```

## 사용법

메뉴 막대 아이콘을 클릭하면 다음 메뉴가 열립니다. 아이콘을 실수로 클릭해도 설정은 바뀌지 않고, 메뉴에서 항목을 골라야만 바뀝니다.

| 항목 | 설명 |
| --- | --- |
| 자연스러운 스크롤: 켬 / 끔 | 현재 상태 (선택할 수 없음) |
| 자연스러운 스크롤 끄기 / 켜기 | 방향을 바로 전환 |
| 로그인 시 실행 | 로그인 항목 등록/해제 |
| 종료 (⌘Q) | 앱 종료 |

## 동작 방식

- **마우스 감지** ([src/MouseWatcher.swift](src/MouseWatcher.swift)): IOKit HID 매니저로 마우스 장치가 연결되거나 제거되는 것을 감시합니다. 트랙패드도 HID 마우스로 잡히기 때문에 내장 장치, 이름에 "trackpad"가 들어간 장치, USB/Bluetooth가 아닌 가상 장치는 제외합니다. 장치를 열지 않고 목록만 읽으므로 입력 모니터링 권한이 필요 없습니다.
- **스크롤 방향 변경** ([src/ScrollDirection.swift](src/ScrollDirection.swift)): 시스템 설정의 "자연스러운 스크롤" 체크박스가 쓰는 비공개 프레임워크 `PreferencePanesSupport`의 `swipeScrollDirection` / `setSwipeScrollDirection` 함수를 `dlopen`으로 불러 사용합니다.
- **외부 변경 감지** ([src/main.swift](src/main.swift)): 시스템 설정 등 다른 곳에서 방향을 바꾸면 `SwipeScrollDirectionDidChangeNotification` 분산 알림을 받아 아이콘을 갱신합니다.

비공개 API를 사용하기 때문에 이후 macOS 업데이트에서 동작하지 않을 수 있습니다. 함수를 찾지 못하면 실행할 때 경고를 띄우고, 이후에는 현재 상태만 표시합니다.

## 프로젝트 구조

```
ScrollToggle/
├── build.sh                  # 앱 번들 빌드 및 ad-hoc 서명
├── src/
│   ├── main.swift            # 앱 진입점, 메뉴 막대 UI, 로그인 항목
│   ├── MouseWatcher.swift    # 외장 마우스 연결 감지
│   └── ScrollDirection.swift # 자연스러운 스크롤 읽기/쓰기
└── icon/
    ├── AppIcon.svg           # 64px 이상용 원본 아이콘
    ├── AppIcon-32px.svg      # 32px용
    ├── AppIcon-16px.svg      # 16px용
    ├── AppIcon.icns          # 빌드에 들어가는 아이콘
    ├── make_icon.swift       # SVG → AppIcon.icns 변환
    └── classic/              # 이전 아이콘 (참고용)
```

## 아이콘 다시 만들기

SVG를 수정했다면 프로젝트 루트에서 다음을 실행해 `icon/AppIcon.icns`를 다시 만든 뒤 빌드하세요.

```sh
swift icon/make_icon.swift
./build.sh
```

## 라이선스

[PolyForm Strict License 1.0.0](LICENSE)을 따릅니다. 소스 코드는 공개되어 있지만 오픈 소스는 아닙니다. 개인적, 비상업적 목적으로 빌드해서 사용하는 것은 허용되지만, 수정하거나 재배포하는 것은 허용되지 않습니다.
