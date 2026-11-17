---
title: 개인정보 처리방침
permalink: /privacy-ko
lang: ko
---

# AgentOffice 개인정보 처리방침

*시행일: 2026년 11월 17일* · [English](privacy)

AgentOffice는 Claude Code 작업을 Mac과 iPhone에서 픽셀 아트 사무실로 보여 주는 앱입니다. 어떤 *종류의* 일을 하고 있는지만 보여 주고, 작업 내용 자체는 보여 주지 않도록 만들었습니다.

**요약:** 개발자는 서버를 운영하지 않으며 어떤 정보도 수집하지 않습니다. 데이터는 사용자의 기기와 사용자 본인의 비공개 iCloud 데이터베이스에만 있습니다. 분석 도구, 광고, 추적이 없고 제3자와 공유하지 않습니다.

## Mac에 기록되는 정보

Claude Code용 AgentOffice 플러그인은 세션마다 작은 기록을 `~/Library/Application Support/AgentOffice/Events`에 남기며, 이 파일은 사용자의 macOS 계정만 읽을 수 있습니다. 한 줄에는 다음만 들어갑니다.

- 시각과 일어난 일의 종류 (예: 도구 사용 시작, 세션 종료)
- 세션 ID, 팀원(서브에이전트)의 ID와 종류 (예: "ios-developer")
- 도구 이름 (예: "Bash", "Read")
- 프로젝트 **폴더 이름**(전체 경로가 아님)과, 폴더 이름이 바뀌어도 같은 층을 유지하기 위해 Mac에서 그 폴더를 구별하는 번호
- 알림의 종류, 세션이 시작되거나 끝난 이유

프롬프트, 도구 입력값, 명령어, 파일 내용, 전체 경로는 **절대** 기록하지 않습니다.

**허락 요청만 예외입니다.** Mac 앱이 열려 있을 때 Claude Code가 도구 사용 허락을 물으면, 플러그인은 안전하게 판단할 수 있도록 실행할 명령어나 파일을 한 줄로 요약해 `~/Library/Application Support/AgentOffice/Approvals`에 질문을 저장합니다. 이 파일은 사용자의 macOS 계정만 읽을 수 있으며, Mac, iPhone, 터미널 중 어디에서든 답하면 바로 삭제됩니다.

## iCloud로 가는 정보

iPhone에서 사무실을 보여 주기 위해 Mac 앱은 **사용자의 비공개 iCloud 데이터베이스**에 데이터를 저장합니다. 사용자의 Apple 계정만 읽을 수 있고, 개발자는 읽을 수 없습니다.

- 사무실의 각 직원: 짧은 이름, 프로젝트 폴더 이름, 방, 상태, 역할, 마지막 활동 시각
- Mac이 마지막으로 연결된 시각
- 열려 있는 허락 요청: 세션 ID, 팀원 ID, 직원의 짧은 이름, 프로젝트 폴더 이름, 도구 이름, 시각, 그리고 사용자가 답한 결과. 명령어나 파일 요약은 **종단간 암호화**되어 저장되므로 사용자 본인의 기기만 읽을 수 있고 Apple도 읽을 수 없습니다. 각 질문은 답하면 삭제됩니다.

새 질문이 오면 iCloud가 Apple의 푸시 서비스로 iPhone에 알림을 보냅니다. 알림에는 직원 이름과 도구 이름만 들어가고 명령어는 들어가지 않습니다.

## 앱이 요청하는 권한

- **Mac: 사용자가 고른 폴더.** 앱은 App Sandbox 안에서 실행되며 사용자가 고른 AgentOffice 폴더만 사용합니다.
- **Mac과 iPhone: 알림.** 허락 요청을 알려 주기 위해 사용하며, 설정에서 언제든 끌 수 있습니다.
- **iCloud.** Mac과 iPhone 사이에서 사무실을 동기화합니다. iCloud 없이도 Mac 앱은 단독으로 작동합니다.

## 데모 사무실

데모 사무실은 기기 안에서 만들어 내는 가상의 내용입니다. 저장하거나 iCloud로 보내거나 Claude Code에 전달하지 않으며, 데모의 허락 요청에 답해도 아무것도 실행되지 않습니다.

## 충돌 보고서

사용자가 기기 설정에서 앱 개발자와 충돌 보고서나 분석 정보를 공유하도록 선택하면, Apple이 개발자에게 익명의 충돌 보고서를 보낼 수 있습니다. 이는 AgentOffice가 아니라 Apple과 사용자가 관리합니다.

## 데이터 삭제

- **Mac:** `~/Library/Application Support/AgentOffice` 폴더를 삭제합니다. 기록을 멈추려면 Claude Code에서 플러그인을 제거합니다.
- **iCloud:** iPhone의 설정 앱에서 이름을 누르고 **iCloud**로 들어가 AgentOffice의 저장 공간을 관리합니다. iCloud의 데이터는 사무실 상태가 바뀔 때마다 새 내용으로 바뀝니다.

## 아동

AgentOffice는 소프트웨어 개발자를 위한 도구이며 아동을 대상으로 하지 않습니다.

## 변경

이 방침이 바뀌면 새 시행일과 함께 이 페이지에 게시합니다. 모든 변경 기록은 [프로젝트 저장소](https://github.com/YUJEONGLEEEEE/AgentOffice/commits/main/docs/privacy-ko.md)에 공개되어 있습니다.

## 문의

개인정보 관련 문의는 [github.com/YUJEONGLEEEEE/AgentOffice/issues](https://github.com/YUJEONGLEEEEE/AgentOffice/issues)에 이슈를 남겨 주세요.

AgentOffice는 독립 프로젝트이며 Anthropic과 제휴하거나 Anthropic의 보증을 받지 않았습니다.
