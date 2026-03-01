# RemindMe 설정 가이드

## Firebase 익명 인증 활성화

알람 데이터를 Firestore에 저장하고 재부팅 후 복원하려면 Firebase 익명 인증을 활성화해야 합니다.

### 1. Firebase Console 접속
https://console.firebase.google.com/

### 2. 프로젝트 선택
`remindme-b2ae5` 프로젝트 선택

### 3. Authentication 설정
1. 왼쪽 메뉴에서 **Authentication** 클릭
2. **Sign-in method** 탭 클릭
3. **익명(Anonymous)** 제공업체 찾기
4. **사용 설정** 토글을 켜기
5. **저장** 클릭

### 4. Firestore 보안 규칙 배포
```bash
firebase deploy --only firestore:rules
```

## 알람 재부팅 복원 기능

### 작동 원리
1. **알람 추가 시**: Firestore에 저장 + 로컬 알람 스케줄링
2. **재부팅 후**: 앱 시작 시 Firestore에서 활성 알람 조회 → 다시 스케줄링
3. **알람 삭제 시**: Firestore 삭제 + 로컬 알람 취소
4. **알람 토글 시**: Firestore 업데이트 + 로컬 알람 활성/비활성

### 테스트 방법
1. 앱에서 알람 1-2개 추가
2. 기기 재부팅
3. 앱 재실행 → 알람이 자동으로 복원됨
4. 알람 시간이 되면 정상적으로 알림 발생

### 동기화 버튼
상단 오른쪽 동기화(🔄) 버튼:
- Firestore의 활성 알람을 로컬에 다시 스케줄링
- 알람이 누락된 경우 수동으로 복원 가능

## 권한 요구사항

### Android
- `POST_NOTIFICATIONS`: 알림 표시 (Android 13+)
- `SCHEDULE_EXACT_ALARM`: 정확한 시간 알람
- `RECEIVE_BOOT_COMPLETED`: 재부팅 감지
- `WAKE_LOCK`: 화면 꺼짐 상태에서 알람

### iOS
- 알림 권한: 앱 최초 실행 시 자동 요청
- 백그라운드 모드: 알람 동작 보장

## 문제 해결

### 알람이 재부팅 후 사라지는 경우
1. Firebase 익명 인증이 활성화되었는지 확인
2. 앱 로그에서 "알람 복원 시작..." 메시지 확인
3. 동기화 버튼(🔄)을 눌러 수동 복원 시도

### 알림이 오지 않는 경우
1. 알림 권한이 허용되었는지 확인
2. 기기의 배터리 최적화 설정 확인
3. 알람 시간이 현재보다 미래인지 확인

### Firestore 접근 오류
1. Firebase Console에서 익명 인증 활성화 확인
2. Firestore 보안 규칙이 배포되었는지 확인
3. 앱을 재시작하여 인증 상태 갱신
