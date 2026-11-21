"""Validate a local OpenAI-compatible JSON response for one synthetic incident."""
import argparse
import json
import os
import sys
from urllib.request import Request, urlopen


def validate(response):
    choice = response["choices"][0]
    message = choice["message"]
    if choice.get("finish_reason") != "stop" or message.get("refusal"):
        raise ValueError("incomplete or refused response")
    data = json.loads(message["content"])
    if not isinstance(data, dict) or set(data) != {"component", "cause"}:
        raise ValueError("expected exactly component and cause")
    if data["component"] not in ("db", "network", "app") or not isinstance(data["cause"], str):
        raise ValueError("invalid component enum or cause type")
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default=os.environ.get("MODEL"))
    parser.add_argument("--stdin", action="store_true", help="validate a captured response offline")
    args = parser.parse_args()
    if args.stdin:
        response = json.load(sys.stdin)
    else:
        if not args.model:
            parser.error("pass --model with a name from `ollama list`")
        schema = {"type": "object", "required": ["component", "cause"], "additionalProperties": False,
                  "properties": {"component": {"type": "string", "enum": ["db", "network", "app"]},
                                 "cause": {"type": "string"}}}
        payload = {"model": args.model, "temperature": 0, "stream": False,
                   "response_format": {"type": "json_schema", "json_schema":
                                       {"name": "diag", "strict": True, "schema": schema}},
                   "messages": [{"role": "user", "content": "Return JSON with component and cause: mysqld killed on OOM."}]}
        req = Request("http://127.0.0.1:11434/v1/chat/completions",
                      data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
        with urlopen(req, timeout=120) as res:
            response = json.load(res)
    result = validate(response)
    print("Schema: PASS;", json.dumps(result, ensure_ascii=False))
    if result["component"] != "db":
        sys.exit("Classification: FAIL (expected db)")
    print("Classification: PASS (one synthetic ticket)")


if __name__ == "__main__":
    main()
