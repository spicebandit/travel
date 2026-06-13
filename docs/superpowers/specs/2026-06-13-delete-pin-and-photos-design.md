# 여행 삭제 PIN 보호 + 일정/여행 사진 기능 — 설계 문서

작성일: 2026-06-13
대상 파일: `index.html` (단일 파일 앱, Supabase 백엔드)

## 배경

- 앱은 Supabase의 `trips` 테이블에 전체 여행 데이터를 JSON 한 덩어리(`id='family'`)로 저장한다.
- 진입 시 PIN 잠금 화면이 있다. PIN은 `localStorage.travel_pin`(없으면 `DEFAULT_PIN='9532'`), `getStoredPin()`으로 조회.
- 메인 화면 여행 리스트의 각 카드에 🗑️ 삭제버튼(`deleteTrip(tripId)`)이 있어 `confirm()`만으로 즉시 삭제된다 → 실수로 전체 여행을 날릴 위험.

## 목표

1. **삭제 PIN 보호**: 메인 리스트의 여행 삭제 시 진입 PIN을 입력해야만 삭제되도록 한다. 개별 일정 삭제는 변경하지 않는다.
2. **사진 기능**: 여행 대표사진 1장 + 일정 항목별 사진 1장을 기록할 수 있게 한다. Supabase Storage 사용.

## 비목표 (YAGNI)

- 일정/여행당 여러 장 사진(현재는 각 1장 제한).
- 사진 갤러리/슬라이드쇼, 캡션, 정렬.
- 개별 일정 삭제에 대한 PIN 보호.
- 사용자 인증(가족용 단일 PIN 앱 유지).

---

## 기능 1: 삭제 PIN 보호

### 동작
- `deleteTrip(tripId)` 진입 시 `prompt('이 여행을 삭제하려면 PIN을 입력하세요')`로 입력받는다.
- 취소(null) → 아무 동작 없이 종료.
- 입력값 !== `getStoredPin()` → `alert('PIN이 틀렸습니다. 삭제가 취소되었습니다.')` 후 종료.
- 일치 → 기존 `confirm('이 여행을 삭제하시겠습니까?')` 유지하고, 확인 시 기존 삭제 로직 실행.

### 구현
- `deleteTrip` 함수 상단에 PIN 검증 블록 추가. 나머지 로직(`trips.filter` → `renderMain` → `saveToServer`)은 그대로.
- PIN은 4자리 숫자라 `prompt`에 잠깐 노출되지만 가족용으로 허용.

---

## 기능 2: 사진 기능 (Supabase Storage)

### 사전 설정 (사용자가 Supabase 대시보드에서 1회 수행)
1. Storage → New bucket: 이름 `travel-photos`, **Public bucket ON**.
2. SQL Editor에서 anon 역할 전체 권한 정책 실행:
   ```sql
   create policy "travel_photos_all_anon"
   on storage.objects for all
   to anon
   using ( bucket_id = 'travel-photos' )
   with check ( bucket_id = 'travel-photos' );
   ```

### 데이터 모델 (기존 JSON에 필드 추가, 하위호환)
- 여행 객체: `coverPhoto` (string, 공개 URL 또는 미설정 시 undefined)
- 일정 항목: `photo` (string, 공개 URL 또는 미설정 시 undefined)
- 기존 데이터에 필드가 없어도 정상 동작해야 한다(옵셔널 체크).

### 저장 경로 규칙
- 대표사진: `cover/{tripId}.jpg`
- 일정사진: `item/{tripId}/{itemId}.jpg`
- 업로드는 `upsert:true`로 같은 경로 덮어쓰기(1장 제한 자연 구현).
- 덮어쓰기 시 브라우저 캐시 회피를 위해 저장 URL에 `?t={타임스탬프}` 캐시버스터를 붙여 필드에 저장.

### 업로드 흐름 (공통 헬퍼 `uploadPhoto(file, path)`)
1. 입력: `<input type="file" accept="image/*">`에서 받은 File.
2. **클라이언트 압축**: canvas로 최대 변 1280px로 리사이즈, `toBlob('image/jpeg', 0.8)`. 보통 100~300KB.
3. `sb.storage.from('travel-photos').upload(path, blob, { upsert:true, contentType:'image/jpeg' })`.
4. `sb.storage.from('travel-photos').getPublicUrl(path)` → 공개 URL.
5. 반환: `publicUrl + '?t=' + Date.now()`.
6. 호출부에서 해당 필드에 저장 후 `saveToServer()` + 재렌더.

### 삭제 흐름
- 필드를 비우고 `saveToServer()`. (Storage 원본은 다음 업로드 시 덮어써지므로 즉시 삭제는 선택. 깔끔하게 `sb.storage.from(...).remove([path])`도 호출.)

### UI 표시
1. **메인 리스트 카드** (`renderMain`): `trip.coverPhoto` 있으면 카드 상단/측면에 썸네일 표시.
2. **여행 상세 상단** (`renderTrip`/헤더 영역): 대표사진 표시 + "대표사진 추가/변경" 버튼.
3. **일정 상세 모달** (`openDetail`): `item.photo` 있으면 이미지 표시. 버튼: "사진 추가/변경", 사진 있을 때 "사진 삭제".
   - 업로드 중에는 버튼 비활성화 + "업로드 중..." 표시.
   - 실패 시 `alert`로 메시지.

### 에러 처리
- 업로드/저장 실패 → `alert('사진 업로드 실패: ' + 메시지)`, 필드 미변경.
- 압축 실패(예: 손상 파일) → 알림 후 중단.

---

## 검증 (단일 HTML, 테스트 프레임워크 없음 → 브라우저 수동 검증)

### 삭제 PIN
- [ ] 삭제 버튼 → PIN 입력창. 틀린 PIN → 삭제 안 됨.
- [ ] 취소 → 삭제 안 됨.
- [ ] 맞는 PIN → confirm → 삭제 및 서버 반영.
- [ ] 개별 일정 삭제는 종전대로 동작.

### 사진
- [ ] 일정 상세에서 사진 업로드 → 표시됨, 새로고침 후에도 유지(서버 저장 확인).
- [ ] 같은 일정에 다른 사진 업로드 → 교체됨(캐시버스터로 즉시 갱신).
- [ ] 사진 삭제 → 사라짐, 서버 반영.
- [ ] 여행 대표사진 업로드 → 메인 카드 썸네일 + 상세 상단 표시.
- [ ] 사진 없는 기존 데이터도 에러 없이 렌더.

## 영향 범위
- 수정 함수: `deleteTrip`, `renderMain`, `openDetail`, 여행 상세 렌더 부분.
- 신규: `uploadPhoto` 헬퍼, 압축 헬퍼, 사진 관련 핸들러(`setItemPhoto`, `setCoverPhoto`, `removeItemPhoto` 등), 관련 CSS, 숨겨진 file input.
- 기존 데이터 스키마 하위호환 유지.
