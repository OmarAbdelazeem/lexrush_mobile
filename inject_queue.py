import asyncio
import json
import websockets

VM_WS_URL = "ws://127.0.0.1:61687/S9PjUCvpSd4=/ws"
ISOLATE_ID = "isolates/7777359905122071"

async def main():
    payload = '[{"id":"test-pending-123","userId":"c6387d69-a6fd-4b7c-af50-0db42401516f","gameId":"antonym_rush","sessionId":"c7444d69-bbcd-4c00-ad11-ee7bcc17b746","request":{"clientEndedAt":"2026-06-05T01:30:00Z","completedPrompts":[{"promptId":"54d2e82d-bb43-4dc9-9d7a-8fbc976865d6","isCorrect":true,"timeSpentMs":1500},{"promptId":"e855a9b9-d2b3-4632-959f-d31e5f8f8ed1","isCorrect":true,"timeSpentMs":1200}],"timeExpired":false},"createdAt":"2026-06-05T01:30:00Z","enqueuedAt":"2026-06-05T01:30:05Z","retryCount":0,"lastAttemptAt":null}]'

    dart_code = f"""
    () async {{
      final prefs = __import__('package:shared_preferences/shared_preferences.dart').SharedPreferencesAsync();
      await prefs.setString('lexrush.pending_results.v1', '{payload}');
      return "Done";
    }}()
    """

    # We need to find the root library to evaluate
    async with websockets.connect(VM_WS_URL) as ws:
        msg = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "evaluate",
            "params": {
                "isolateId": ISOLATE_ID,
                "targetId": "libraries/@30449832", # main.dart
                "expression": dart_code,
                "disableBreakpoints": True
            }
        }
        await ws.send(json.dumps(msg))
        response = await ws.recv()
        print(response)

asyncio.run(main())
