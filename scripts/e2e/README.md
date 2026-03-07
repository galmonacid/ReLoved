# Chrome E2E

## Local run

```bash
scripts/e2e/run_chat_e2e.sh
```

This runs the Chrome-visible suite against Firebase emulators and executes:

- `integration_test/chat_send_message_test.dart`
- `integration_test/chat_receive_live_message_test.dart`
- `integration_test/chat_inbox_preview_test.dart`
- `integration_test/auth_search_smoke_test.dart`

## Requirements

- `chromedriver` available in `PATH`
- Java 21 available at `~/.local/jdk-21/Contents/Home` or via `JAVA_HOME`
- Flutter SDK
- Firebase CLI

## Headless / CI-style run

```bash
E2E_HEADLESS=1 E2E_DEVICE=web-server scripts/e2e/run_chat_e2e.sh
```
