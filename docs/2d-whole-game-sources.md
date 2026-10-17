# 2D 전체 게임 소스 후보 · 2026-10-18

## 결론

부분 기능을 기존 main.gd에 붙이는 방식은 중단한다. 다운로드 및 원본 구조 확인을 마친 전체 프로젝트를 별도 Git submodule로 보존한다. 현재 우선 후보는 OpenClonk이며, 최종 모바일 기반 채택은 원본 실행과 이식 비용 확인 후 결정한다. 무료라고 무오류이거나 모바일에 적합한 것은 아니다.

| 후보 | 실제 구성 | 권리 조건과 판단 |
| --- | --- | --- |
| Ironbound | 통합된 3D RTS/도시 운영 게임, Godot | 코드 MIT. 모델·음악 등은 ASSET_CREDITS.md에서 별도 확인. 기존에 다운로드·실행·별도 Web 배포함. 여관과 장르 차이가 큼 |
| OpenClonk | 횡단면 지형 파괴·채굴·건설·운반·생산 게임, C++ 엔진 + C4Script | 코드 ISC, planet/COPYING은 CC BY 3.0이며 개별 콘텐츠에 다른 라이선스가 있을 수 있음. 저작권/크레딧/변경 표시 및 개별 에셋 조건 유지. TRADEMARK 별도 준수. 전체 원본 확보 우선 후보 |
| Minicraft+ | 탑다운 2D 생존·건설·제작·저장 게임, Java | GPL-3.0. 수정본 배포 시 해당 파생 프로그램의 대응 소스 제공 등 GPL 의무. 비공개 상용 소스로 바꾸기에는 부적합. 공식 README가 main의 불안정을 경고하여 2.3.0-dev 지점 고정 |
| Souvlaki42/2d-sandbox | Godot 4.7의 테라리아풍 지형·채굴 프로젝트 | 자체 코드 Unlicense. Kenney 및 다른 외부 에셋 별도. 실제 clone/import에서 누락 텍스처와 타일 오류 확인. 완성 게임 기반으로 채택하지 않음 |
| GoTeria / 여러 Terraria clone | 테라리아풍 프로젝트 | Godot 3 또는 명확한 재사용 라이선스 부재, 개발단계 차이. 공개 저장소라는 이유로 상용 재사용 가능하다고 판단하지 않음 |
| tModLoader | 테라리아 모드 제작 도구 | Terraria 모드 제작 경로. MIT인 모딩 도구와 Terraria 원작 재배포 권리는 별개. 독립 상용 게임의 무료 원본 대체재로 취급하지 않음 |

## 이번에 실제로 한 일

- OpenClonk 전체 Git 저장소 다운로드: 36de799544af0459014ea088867fe263779a8bdd.
- Minicraft+ 전체 Git 저장소 다운로드: 4dc00332e24a727b96be7b885d5cbbdd9c85263c (2.3.0-dev).
- 엔진 소스와 게임 콘텐츠, 라이선스, 빌드 설명을 읽음. 일부 스크립트 추출/합성 없음.
- 두 프로젝트를 foundations 아래 독립 Git submodule로 등록. 전체 다운로드는 `git submodule update --init --recursive`.
- 원본 파일 수정 및 여관 기능 추가는 아직 하지 않음.
- OpenClonk는 이 환경에서 빌드/플레이하지 않았음. 기존 Godot 실행기로 열 수 없음.
- Minicraft+ Gradle 빌드는 services.gradle.org 다운로드 단계에서 환경의 네트워크 연결 제한으로 중단. 게임 코드 컴파일 실패 또는 성공으로 해석하지 않음.
- Godot 2d-sandbox는 실제 import 오류를 확인하여 제외. 저장소 소개와 체크리스트만으로 안정성을 인정하지 않음.

## OpenClonk를 먼저 보는 이유와 한계

횡단면 땅 파기, 통로 연결, 물체 운반, 건물 제작이 게임 안에 함께 존재한다. 여관 아래를 확장하는 구조에는 3D 전쟁 RTS보다 가깝다. 단, 여관 숙박/접수/손님/식당/수감자 시뮬레이션은 원본 기능이라고 주장하지 않는다. PC 전용 성격의 입력과 전용 엔진 때문에 세로 모바일/웹 전환은 큰 작업일 수 있다. Godot로 재작성하면 전체 원본 채택의 이점이 사라지므로, 이식하지 않고 먼저 원본 엔진의 시나리오와 C4Script로 수정 가능성을 판단한다.

## 수정 순서

1. OpenClonk 원본 Windows 배포본과 동일 버전 소스의 재현 빌드 확보.
2. 기존 원본 건설/채굴/운반 입력을 유지한 작은 지상 건물 + 지하 시나리오.
3. 이동/클릭/채굴/배치 원본 동작을 직접 비교한 뒤 여관 자원 순환 추가.
4. 모바일 이식이 감당되지 않으면 먼저 명확히 중단 판단. 임의로 Godot에 기능만 복사하지 않음.

## 원문

- https://github.com/destinjones/ironbound/blob/main/LICENSE
- https://github.com/destinjones/ironbound/blob/main/ASSET_CREDITS.md
- https://github.com/openclonk/openclonk
- https://github.com/openclonk/openclonk/blob/master/COPYING
- https://github.com/openclonk/openclonk/blob/master/planet/COPYING
- https://github.com/openclonk/openclonk/blob/master/TRADEMARK
- https://www.openclonk.org/download/
- https://github.com/MinicraftPlus/minicraft-plus-revived
- https://github.com/Souvlaki42/2d-sandbox
- https://github.com/tModLoader/tModLoader
