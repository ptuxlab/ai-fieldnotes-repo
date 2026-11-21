# Case 03 · A valid JSON response can still be wrong

Select an installed model from `ollama list`, then run `python3 check_response.py --model YOUR_LOCAL_MODEL`. The request is sent only to the local Ollama server. HTTP errors, a refusal, incomplete output, invalid JSON, extra properties, an invalid enum, and the wrong class all produce a nonzero exit status. One passing synthetic ticket establishes neither dataset accuracy nor which grammar engine was used.

For an offline check, pipe a captured Chat Completions response into `python3 check_response.py --stdin`. Expected output is two separate decisions: `Schema: PASS` and, for this particular OOM input, `Classification: PASS`.
