# ODROID-M1 (bsp-odroidm1)

## Vanilla Batocera 대비 추가된 기능

- 하드커널 자체 BSP 커널(**Linux 6.1.141**)을 씀 — 메인라인 대신 사용
  - VU8M, 모노 오디오, USB3.0 지원에 필요
- VU8M(하드커널 8인치 DSI 터치스크린) 지원
- 벤더 Mali G52 blob(g29p1 세대)을 씀 — GLES + Vulkan
- Wayland(labwc) 컴포지터 지원 — PCSX2/Dolphin/AetherSX2 등 standalone Qt 기반 에뮬레이터 실사용 가능
- 모노 스피커 볼륨/출력 라우팅 수정(기본 볼륨이 너무 작던 문제 해결)
- FBNeo 한국어 패치 코어(`fbneo_korean`)를 기본값으로 씀
- AetherSX2(PS2)를 기본값으로 넣음 — mainline PCSX2 계열이 겪는 Mali GPU 폴트를 피하는 대안 코어
- PS2/GameCube/Dreamcast/PSP 등 주요 시스템 Vulkan 렌더링 지원
- 시스템별 자동(auto) 코어/API 선택을 실측 최고 성능 기준으로 다시 맞춤

## 설정

### 디스플레이 (HDMI / VU8M)

- **HDMI**: 기본 활성화, 별도 설정 불필요(1080p까지 테스트 완료).
- **VU8M**: 기본 비활성화. **BATOCERA** 파티션(SD카드를 컴퓨터에 꽂으면 보이는 드라이브)의 `config.ini`에서 켤 것:
  ```
  overlays="display_vu8m"
  ```
  끄려면 다시 `overlays=""`. DSI 패널은 핫플러그 감지가 안 되므로, 켜두면 실제로 패널이 꽂혀있지 않아도 항상 "연결됨"으로 잡힘 — 안 쓸 땐 꺼둘 것.

### 백글래스 / 화면 회전

**백글래스로 쓰기**: VU8M을 메인 화면(HDMI) 게임 중 박스아트/게임 정보를 보여주는 보조 화면으로 쓰려면, ES 메뉴 **MULTISCREENS → BACKGLASS / INFORMATION SCREEN**에서 두 번째 비디오 출력으로 VU8M을 지정. **이 지정을 해야만** ES가 그 출력을 실제로 구성(해상도/회전 적용)함 — 비워두면 HDMI 옆에 이어붙는 미사용 확장 화면으로만 잡히고 아무것도 제대로 안 나옴.

**예외 — NDS 듀얼스크린**: NDS는 원래 화면이 위/아래 두 개라, HDMI+VU8M을 동시에 켜고 `melonDS` 코어를 쓰면 실제 물리 화면 두 개에 NDS의 위/아래 화면을 각각 나눠 출력할 수 있음. 다만 melonDS는 이 보드에서 성능이 안 좋아서(GPU가속 켜도 기본 권장 코어 drastic 대비 훨씬 느림) **사실상 실사용은 힘듦** — 듀얼스크린이 정말 꼭 필요한 경우가 아니면 기본값인 drastic(단일 화면)을 쓸 것.

**회전 설정**: ES 메뉴(위 MULTISCREENS 섹션의 SCREEN ROTATION)에서 하는 게 정석 — 여기서 고른 값이 **SHARE 파티션**(SD카드를 컴퓨터에 꽂으면 보이는 두 번째 드라이브)의 `system/batocera.conf`에 저장됨. 이 파티션을 마운트해서 직접 편집하거나, SSH로:
```
batocera-settings-set global.videooutput2 DSI-1   # VU8M을 2번째 화면(백글래스)으로 지정
batocera-settings-set display.rotate2.DSI-1 3      # 그 화면의 회전값
reboot
```
메인 화면 회전은 커넥터별로 `display.rotate.<커넥터이름>=<N>`(예: `display.rotate.HDMI-A-1`), 없으면 전역 `display.rotate=<N>`. `<N>`은 `0`(정상), `1`(90도), `2`(180도), `3`(270도) — 메인 화면 회전은 부팅 스플래시에도 재부팅 시점에 자동 반영됨(vanilla 메커니즘, 별도 설정 불필요). `display.rotate2`(백글래스)는 여기 해당 안 됨 — 스플래시는 2번째 화면엔 아무것도 안 그림.

**주의**: `system/batocera.conf`는 기기가 **최초 1회 부팅**해서 SHARE 파티션을 초기화해야 생김 — 갓 구운 SD카드를 PC에 바로 꽂으면 이 파일도, `system` 폴더 자체도 없음(최초 부팅 시 Batocera가 SHARE 파티션에 `roms`/`bios`/`saves`/`system` 등 전체 기본 디렉토리 구조를 만듦). 위 설정은 기기를 한 번 부팅시킨 뒤에 할 것.

## 시스템별 성능 측정 결과 및 권장 코어/API

측정 기준 버전: **`batocera44-odroidm1-v1.0.0`**(이 문서는 릴리스마다 최신 상태로 유지 — 이후 버전에서 관련 코어/커널/blob이 바뀌면 재검증 필요), Power Mode = High Performance 고정, Avg FPS/1% Low 기준(프레임타임 기반, 업계 표준 지표). **auto로 실제 적용되는 코어/API는 굵게 표시.**

| 시스템 | 게임 | 코어 | API | Avg FPS | 1% Low |
| --- | --- | --- | --- | --- | --- |
| Genesis/Mega Drive | Altered Beast | **genesisplusgx** | — | **60.0** | 50.3 |
| | | genesisplusgx-expanded | — | 60.0 | 47.6 |
| | | picodrive | — | 60.0 | 48.5 |
| FBNeo | 야구격투 리그맨 | **fbneo_korean** | — | **60.0** | 41.0 |
| Saturn | Strikers 1945 | **yabasanshiro** | GLES | **59.3** | 24.3 |
| | | beetle-saturn | GLES | 22.5 | 16.8 |
| | | beetle-saturn | Vulkan | 22.8 | 16.4 |
| PSX | Soul Blade | **pcsx_rearmed** | GLES | **60.0** | 38.9 |
| | | pcsx_rearmed | Vulkan | 60.0 | 42.0 |
| | | swanstation | GLES | 58.5 | 32.1 |
| | | swanstation | Vulkan | 59.3 | 34.5 |
| | | mednafen_psx | GLES | 29.0 | 19.6 |
| | | mednafen_psx | Vulkan | 31.3 | 20.7 |
| N64 | 요시스토리 | standalone mupen64plus(**rice**) | GLES | **59.6** | 30.3 |
| | | standalone mupen64plus(glide64mk2) | GLES | 54.9 | 13.0 |
| | | standalone mupen64plus(gliden64) | GLES | 10.3 | 3.6 |
| | | libretro mupen64plus-next | GLES | 59.5 | 24.5 |
| | | libretro parallel_n64 | GLES | 56.2 | 17.9 |
| Dreamcast | Soulcalibur | **standalone flycast** | **Vulkan** | **55.5** | 11.7 |
| | | standalone flycast | GLES | 56.4 | 13.0 |
| | | libretro flycast | GLES | 55.9 | 10.1 |
| | | libretro flycast | Vulkan | 56.0 | 13.1 |
| PS2 | 2002 FIFA World Cup(Korea) | **AetherSX2** | **Vulkan** | **23.8** | 4.2 |
| GameCube | Pikmin | **standalone Dolphin** | **Vulkan** | **29.7** | 8.4 |
| PSP | Tekken 6 | **standalone PPSSPP** | **Vulkan** | **58.9** | 27.0 |
| | | standalone PPSSPP | GLES | 54.0 | 17.7 |
| | | libretro ppsspp | GLES | 54.2 | 16.1 |
| | | libretro ppsspp | Vulkan | 54.1 | 27.0 |
| NDS | (매트릭스 측정 제외 — 3트랙 모두 99%+ 여유로 일찌감치 결론남) | **drastic** | — | — | — |

**참고**:
- Genesis/FBNeo는 소프트웨어 2D 렌더링이라 API(GLES/Vulkan) 구분 자체가 의미 없음.
- N64/Dreamcast의 libretro Vulkan 코어(mupen64plus-next, parallel_n64)는 소리만 나오고 화면이 안 뜨는 알려진 문제가 있어 위 표에서 제외함(GLES만 비교 가능).
- Wii는 GameCube와 같은 원리(standalone Dolphin + Vulkan)로 별도 성능 측정은 안 했지만 동일하게 권장.

## 알려진 제약

- **PS2 `pcsx2` 코어**(mainline PCSX2 계열): 이 코어들이 쓰는 신형 GS 커맨드 패턴이 Mali G52 GPU의 진짜 하드웨어 폴트(`DATA_INVALID_FAULT`)를 유발함 — dmesg 로그와 실제 게임 멈춤으로 확인됨. AetherSX2(구형 GS 커맨드 패턴을 쓰는 PCSX2 계열 포크)는 이 폴트를 회피해서 기본값으로 씀. `pcsx2`도 EmulationStation에 설치+선택 가능한 상태로 남겨뒀음(실험해보고 싶은 사람용).
