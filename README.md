# YPMacro: G Macro(지매크로) 호환 매크로

[한국어](#한국어) · [English](#english)

## 한국어

G Macro(지매크로, G매크로)와 같은 화면으로 쓰는 무료 Windows 키보드·마우스 매크로입니다.
G Macro로 만든 `.gmc` 파일을 그대로 불러옵니다.

### 기능

- **G Macro `.gmc` 불러오기**: 쓰던 매크로를 다시 만들 필요 없음
- **G Macro와 같은 화면**: 이벤트 목록 + 키보드 / 마우스 / 시간 버튼
- **메모장으로 쓰는 매크로 파일**: `[key w down], [delay 0.5]` 형식의 `.ypm`
- **설정도 파일에 저장**: 테마, 단축키, 반복, 지연
- **테마 4종**: 기본(G Macro 모양) / 다크 / 라떼 / 해커
- **한국어 / English 화면**: 처음에는 Windows 언어를 따르고, `설정 → 언어`에서 바꿀 수 있음
- **설치 없이 exe 하나**, 한글 깨짐 없음

### 다운로드

[Releases](../../releases)에서 최신 exe를 받아 실행합니다. (Windows 10 / 11, 64비트)

"Windows의 PC 보호" 창이 뜨면 **추가 정보 → 실행**을 누르세요.

### 사용법

| 할 일 | 방법 |
|---|---|
| 이벤트 추가 | **키보드 / 마우스 / 시간** 버튼 |
| 중간에 끼워 넣기 | **삽입**을 고른 뒤 추가 (선택한 줄 아래로) |
| 시작 / 중지 | **F9** / **F10** |
| 커서 위치 추가 | **F8** |
| 반복 | **반복** 체크 (횟수: `설정 → 기타 설정`, 0 = 무한) |
| 수정 / 지우기 | 줄 더블클릭 / Delete 키 (우클릭 메뉴도 있음) |
| 저장 / 불러오기 | `파일` 메뉴, 창에 끌어다 놓기, `.ypm` 더블클릭 |
| 단축키·테마·언어 바꾸기 | `설정` 메뉴 |

G Macro 파일은 `파일 → 불러오기`에서 `.gmc`를 고르면 됩니다. G Macro와 같은 속도로 맞출지 물으면 **예**를 누르세요.

### 매크로 파일(.ypm) 쓰는 법

동작 하나를 `[ ]` 하나에 쓰고 쉼표로 이어 쓰면 됩니다. 대괄호 밖의 글은 무시됩니다.

```
[settings theme=dark start=F9 stop=F10 repeat=on],
[key w down], [left click], [delay 0.5], [move 800 465], [key w up]
```

| 동작 | 예 |
|---|---|
| 키 | `[key a]` `[key ctrl+c]` `[key w down]` `[key w up]` `[key a 80ms]` |
| 문장 | `[text Hello]` |
| 마우스 | `[left click]` `[right doubleclick]` `[left down]` `[left up]` `[wheel up]` |
| 커서 이동 | `[move 800 465]` (화면 좌표) `[moveby 10 -5]` (지금 위치에서) |
| 지연 | `[delay 0.5]` (초) `[delay 500ms]` |

맨 앞의 `[settings]`는 없어도 되고, 필요한 항목만 써도 됩니다.

| 설정 | 값 |
|---|---|
| `theme` | `default` `dark` `latte` `hacker` |
| `start` `stop` `capture` | 시작 / 중지 / 커서 위치 추가 단축키 (`F9`, `Ctrl+F9` 등) |
| `repeat` `loops` | 반복 `on` / `off`, 반복 횟수 (0 = 무한) |
| `startdelay` `interval` | 시작 전 지연, 이벤트 간격 (초) |
| `keyhold` | 키 누르는 시간 (`50ms`) |
| `mode` | 입력 방식 `event` / `input` |

### 버그 신고 · 기능 제안

프로그램의 `정보 → 버그 신고 / 기능 제안`, 또는 [Issues](../../issues)

### 참고

- 관리자 권한으로 실행된 프로그램에 입력하려면 YPMacro도 관리자 권한으로 실행하세요.
- 설정은 레지스트리 `HKCU\Software\YPMacro`에 저장됩니다. 프로그램 폴더에는 파일을 만들지 않습니다.
- 게임이나 서비스에서 매크로를 금지하는지 먼저 확인하세요.
- exe는 GitHub Actions가 이 저장소의 소스로 자동 빌드합니다. AutoHotkey v2가 있으면 `YPMacro.ahk`를 바로 실행할 수 있습니다.
- G Macro Second Edition을 참고해 새로 만든 별도 프로그램이며, 원작과는 관계없습니다.

---

## English

A free keyboard & mouse macro tool for Windows with the same layout as G Macro.
Opens G Macro `.gmc` files as they are.

### Features

- **Opens G Macro `.gmc` files**: no need to rebuild your macros
- **Same layout as G Macro**: event list + Keyboard / Mouse / Time buttons
- **Plain-text macro files**: `.ypm`, written like `[key w down], [delay 0.5]`
- **Settings saved in the file**: theme, hotkeys, repeat, delays
- **4 themes**: Default (G Macro look) / Dark / Latte / Hacker
- **English / Korean interface**: follows your Windows language at first; change it in `Settings → Language`
- **Portable**: a single exe, no installation

### Download

Get the latest exe from [Releases](../../releases) and run it. (Windows 10 / 11, 64-bit)

If "Windows protected your PC" appears, click **More info → Run anyway**.

### Usage

| Task | How |
|---|---|
| Add an event | **Keyboard / Mouse / Time** buttons |
| Insert in the middle | Choose **Insert**, then add (goes below the selected row) |
| Start / Stop | **F9** / **F10** |
| Add cursor position | **F8** |
| Repeat | Check **Repeat** (count: `Settings → Other Settings`, 0 = forever) |
| Edit / Delete | Double-click a row / Delete key (right-click menu too) |
| Save / Open | `File` menu, drag a file onto the window, or double-click a `.ypm` |
| Change hotkeys / theme / language | `Settings` menu |

To import a G Macro file, open the `.gmc` via `File → Open`. When asked whether to match G Macro's timing, click **Yes**.

### Writing .ypm files

Write each action in `[ ]` and separate them with commas. Text outside brackets is ignored.

```
[settings theme=dark start=F9 stop=F10 repeat=on],
[key w down], [left click], [delay 0.5], [move 800 465], [key w up]
```

| Action | Examples |
|---|---|
| Key | `[key a]` `[key ctrl+c]` `[key w down]` `[key w up]` `[key a 80ms]` |
| Text | `[text Hello]` |
| Mouse | `[left click]` `[right doubleclick]` `[left down]` `[left up]` `[wheel up]` |
| Move cursor | `[move 800 465]` (screen) `[moveby 10 -5]` (from current position) |
| Delay | `[delay 0.5]` (seconds) `[delay 500ms]` |

The leading `[settings]` is optional, and you can include only the items you need.

| Setting | Value |
|---|---|
| `theme` | `default` `dark` `latte` `hacker` |
| `start` `stop` `capture` | Hotkeys for start / stop / add cursor position (`F9`, `Ctrl+F9`, ...) |
| `repeat` `loops` | Repeat `on` / `off`, number of loops (0 = forever) |
| `startdelay` `interval` | Delay before start, gap between events (seconds) |
| `keyhold` | How long each key is held (`50ms`) |
| `mode` | Input method `event` / `input` |

### Bugs & ideas

In the app: `Help → Report a Bug / Suggest a Feature`, or [Issues](../../issues)

### Notes

- To send input to a program running as administrator, run YPMacro as administrator too.
- Settings are stored in the registry at `HKCU\Software\YPMacro`. No files are created next to the exe.
- Check whether the game or service you use allows macros.
- The exe is built from this repository's source by GitHub Actions. With AutoHotkey v2 installed, you can run `YPMacro.ahk` directly.
- An independent program inspired by G Macro Second Edition; not affiliated with the original.

---

MIT License · The released exe includes the AutoHotkey v2.0.28 interpreter (GPL-2.0, [source](https://github.com/AutoHotkey/AutoHotkey)).
