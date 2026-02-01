#!/usr/bin/env python3
import json


def create_3q_nodes():
    nodes = []

    # 1. Google Sheets - Lookup User
    nodes.append(
        {
            "parameters": {
                "operation": "lookup",
                "sheetId": {"__rl": True, "mode": "url"},
                "range": "={{ $env.GOOGLE_SHEETS_RANGE }}",
                "lookupColumn": "Phone",
                "lookupValue": "={{ $json.phone }}",
                "options": {},
            },
            "name": "Google Sheets - Lookup User",
            "type": "n8n-nodes-base.googleSheets",
            "typeVersion": 4,
            "credentials": {
                "googleSheetsOAuth2Api": {
                    "id": "googleSheetsOAuth2Api",
                    "name": "Google Sheets OAuth2",
                }
            },
        }
    )

    # 2. Code - Extract State
    nodes.append(
        {
            "parameters": {
                "jsCode": "const lookupResult = $input.first().json; const phone = $('Code - Parse SMS').first().json.phone; const conversationState = lookupResult.conversation_state || ''; return [{ json: { phone, conversationState, rowData: lookupResult } }];"
            },
            "name": "Code - Extract State",
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
        }
    )

    # 3. Switch - State Router (5 rules)
    nodes.append(
        {
            "parameters": {
                "rules": {
                    "values": [
                        {
                            "name": "Empty / SMS_Sent",
                            "conditions": {
                                "options": {
                                    "caseSensitive": True,
                                    "leftValue": "",
                                    "typeValidation": "strict",
                                },
                                "conditions": [
                                    {
                                        "id": "condition-empty",
                                        "leftValue": "={{ $json.conversationState }}",
                                        "rightValue": "",
                                        "operator": {
                                            "type": "string",
                                            "operation": "isEmpty",
                                        },
                                    }
                                ],
                                "combinator": "or",
                            },
                        },
                        {
                            "name": "Awaiting PLZ",
                            "conditions": {
                                "options": {
                                    "caseSensitive": True,
                                    "leftValue": "",
                                    "typeValidation": "strict",
                                },
                                "conditions": [
                                    {
                                        "id": "condition-plz",
                                        "leftValue": "={{ $json.conversationState }}",
                                        "rightValue": "awaiting_plz",
                                        "operator": {
                                            "type": "string",
                                            "operation": "equals",
                                        },
                                    }
                                ],
                                "combinator": "and",
                            },
                        },
                        {
                            "name": "Awaiting kWh",
                            "conditions": {
                                "options": {
                                    "caseSensitive": True,
                                    "leftValue": "",
                                    "typeValidation": "strict",
                                },
                                "conditions": [
                                    {
                                        "id": "condition-kwh",
                                        "leftValue": "={{ $json.conversationState }}",
                                        "rightValue": "awaiting_kwh",
                                        "operator": {
                                            "type": "string",
                                            "operation": "equals",
                                        },
                                    }
                                ],
                                "combinator": "and",
                            },
                        },
                        {
                            "name": "Awaiting Photo",
                            "conditions": {
                                "options": {
                                    "caseSensitive": True,
                                    "leftValue": "",
                                    "typeValidation": "strict",
                                },
                                "conditions": [
                                    {
                                        "id": "condition-photo",
                                        "leftValue": "={{ $json.conversationState }}",
                                        "rightValue": "awaiting_foto",
                                        "operator": {
                                            "type": "string",
                                            "operation": "equals",
                                        },
                                    }
                                ],
                                "combinator": "and",
                            },
                        },
                        {
                            "name": "Qualified Complete",
                            "conditions": {
                                "options": {
                                    "caseSensitive": True,
                                    "leftValue": "",
                                    "typeValidation": "strict",
                                },
                                "conditions": [
                                    {
                                        "id": "condition-complete",
                                        "leftValue": "={{ $json.conversationState }}",
                                        "rightValue": "qualified_complete",
                                        "operator": {
                                            "type": "string",
                                            "operation": "equals",
                                        },
                                    }
                                ],
                                "combinator": "and",
                            },
                        },
                    ]
                },
                "options": {},
            },
            "name": "Switch - State Router",
            "type": "n8n-nodes-base.switch",
            "typeVersion": 3,
        }
    )

    # 4. IF - Check JA Response
    nodes.append(
        {
            "parameters": {
                "conditions": {
                    "options": {
                        "caseSensitive": True,
                        "leftValue": "",
                        "typeValidation": "strict",
                    },
                    "conditions": [
                        {
                            "id": "condition-ja",
                            "leftValue": "={{ $('Code - Parse SMS').first().json.response.trim().toLowerCase() }}",
                            "rightValue": "ja",
                            "operator": {"type": "string", "operation": "includes"},
                        }
                    ],
                    "combinator": "and",
                },
                "options": {},
            },
            "name": "IF - Is JA Response",
            "type": "n8n-nodes-base.if",
            "typeVersion": 2,
        }
    )

    # 5. Code - Validate PLZ
    nodes.append(
        {
            "parameters": {
                "jsCode": "const response = $('Code - Parse SMS').first().json.response.trim(); const plzPattern = /^\\d{5}$/; const isValid = plzPattern.test(response); return [{ json: { phone: $('Code - Parse SMS').first().json.phone, response, isValid, fieldType: 'plz' } }];"
            },
            "name": "Code - Validate PLZ",
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
        }
    )

    # 6. Code - Validate kWh
    nodes.append(
        {
            "parameters": {
                "jsCode": "const response = $('Code - Parse SMS').first().json.response.trim(); const numValue = parseFloat(response); const isValid = !isNaN(numValue) && numValue > 0; return [{ json: { phone: $('Code - Parse SMS').first().json.phone, response, isValid, fieldType: 'kwh' } }];"
            },
            "name": "Code - Validate kWh",
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
        }
    )

    # 7. Code - Validate Photo
    nodes.append(
        {
            "parameters": {
                "jsCode": "const numMedia = parseInt($('Code - Parse SMS').first().json.numMedia || '0'); const isValid = numMedia > 0; return [{ json: { phone: $('Code - Parse SMS').first().json.phone, numMedia, isValid, fieldType: 'photo' } }];"
            },
            "name": "Code - Validate Photo",
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
        }
    )

    # 8. Google Sheets - Set State Awaiting PLZ
    nodes.append(
        {
            "parameters": {
                "operation": "update",
                "sheetId": {"__rl": True, "mode": "url"},
                "range": "={{ $env.GOOGLE_SHEETS_RANGE }}",
                "options": {},
                "columns": {
                    "mappingMode": "defineBelow",
                    "value": {"conversation_state": "awaiting_plz"},
                },
            },
            "name": "Google Sheets - Set Awaiting PLZ",
            "type": "n8n-nodes-base.googleSheets",
            "typeVersion": 4,
            "credentials": {
                "googleSheetsOAuth2Api": {
                    "id": "googleSheetsOAuth2Api",
                    "name": "Google Sheets OAuth2",
                }
            },
        }
    )

    # 9. Google Sheets - Set State Awaiting kWh
    nodes.append(
        {
            "parameters": {
                "operation": "update",
                "sheetId": {"__rl": True, "mode": "url"},
                "range": "={{ $env.GOOGLE_SHEETS_RANGE }}",
                "options": {},
                "columns": {
                    "mappingMode": "defineBelow",
                    "value": {
                        "conversation_state": "awaiting_kwh",
                        "plz": "={{ $('Code - Validate PLZ').first().json.response }}",
                    },
                },
            },
            "name": "Google Sheets - Set Awaiting kWh",
            "type": "n8n-nodes-base.googleSheets",
            "typeVersion": 4,
            "credentials": {
                "googleSheetsOAuth2Api": {
                    "id": "googleSheetsOAuth2Api",
                    "name": "Google Sheets OAuth2",
                }
            },
        }
    )

    # 10. Google Sheets - Set State Awaiting Photo
    nodes.append(
        {
            "parameters": {
                "operation": "update",
                "sheetId": {"__rl": True, "mode": "url"},
                "range": "={{ $env.GOOGLE_SHEETS_RANGE }}",
                "options": {},
                "columns": {
                    "mappingMode": "defineBelow",
                    "value": {
                        "conversation_state": "awaiting_foto",
                        "kwh": "={{ $('Code - Validate kWh').first().json.response }}",
                    },
                },
            },
            "name": "Google Sheets - Set Awaiting Photo",
            "type": "n8n-nodes-base.googleSheets",
            "typeVersion": 4,
            "credentials": {
                "googleSheetsOAuth2Api": {
                    "id": "googleSheetsOAuth2Api",
                    "name": "Google Sheets OAuth2",
                }
            },
        }
    )

    # 11. Google Sheets - Set Qualified Complete
    nodes.append(
        {
            "parameters": {
                "operation": "update",
                "sheetId": {"__rl": True, "mode": "url"},
                "range": "={{ $env.GOOGLE_SHEETS_RANGE }}",
                "options": {},
                "columns": {
                    "mappingMode": "defineBelow",
                    "value": {"conversation_state": "qualified_complete"},
                },
            },
            "name": "Google Sheets - Set Qualified Complete",
            "type": "n8n-nodes-base.googleSheets",
            "typeVersion": 4,
            "credentials": {
                "googleSheetsOAuth2Api": {
                    "id": "googleSheetsOAuth2Api",
                    "name": "Google Sheets OAuth2",
                }
            },
        }
    )

    # 12. Twilio SMS - Q1 (PLZ)
    nodes.append(
        {
            "parameters": {
                "operation": "send",
                "from": "={{ $env.TWILIO_PHONE_NUMBER }}",
                "to": "={{ $json.phone }}",
                "body": "Willkommen! Bitte teilen Sie uns Ihre Postleitzahl mit (5-stellig).",
                "options": {"maxTries": 3, "waitBetweenTries": 2000},
            },
            "name": "Twilio - Send Q1 (PLZ)",
            "type": "n8n-nodes-base.twilio",
            "typeVersion": 1,
        }
    )

    # 13. Twilio SMS - Q2 (kWh)
    nodes.append(
        {
            "parameters": {
                "operation": "send",
                "from": "={{ $env.TWILIO_PHONE_NUMBER }}",
                "to": "={{ $json.phone }}",
                "body": "Danke! Wie hoch ist Ihr Jahresstromverbrauch in kWh?",
                "options": {"maxTries": 3, "waitBetweenTries": 2000},
            },
            "name": "Twilio - Send Q2 (kWh)",
            "type": "n8n-nodes-base.twilio",
            "typeVersion": 1,
        }
    )

    # 14. Twilio SMS - Q3 (Photo)
    nodes.append(
        {
            "parameters": {
                "operation": "send",
                "from": "={{ $env.TWILIO_PHONE_NUMBER }}",
                "to": "={{ $json.phone }}",
                "body": "Alles klar! Bitte senden Sie uns ein Foto von Ihrem Stromzähler.",
                "options": {"maxTries": 3, "waitBetweenTries": 2000},
            },
            "name": "Twilio - Send Q3 (Photo)",
            "type": "n8n-nodes-base.twilio",
            "typeVersion": 1,
        }
    )

    # 15. Twilio SMS - Error PLZ
    nodes.append(
        {
            "parameters": {
                "operation": "send",
                "from": "={{ $env.TWILIO_PHONE_NUMBER }}",
                "to": "={{ $json.phone }}",
                "body": "Bitte geben Sie eine gültige 5-stellige Postleitzahl ein.",
                "options": {"maxTries": 3, "waitBetweenTries": 2000},
            },
            "name": "Twilio - Send Error PLZ",
            "type": "n8n-nodes-base.twilio",
            "typeVersion": 1,
        }
    )

    # 16. Twilio SMS - Error kWh
    nodes.append(
        {
            "parameters": {
                "operation": "send",
                "from": "={{ $env.TWILIO_PHONE_NUMBER }}",
                "to": "={{ $json.phone }}",
                "body": "Bitte geben Sie eine gültige kWh-Zahl größer als 0 ein.",
                "options": {"maxTries": 3, "waitBetweenTries": 2000},
            },
            "name": "Twilio - Send Error kWh",
            "type": "n8n-nodes-base.twilio",
            "typeVersion": 1,
        }
    )

    # 17. Twilio SMS - Error Photo
    nodes.append(
        {
            "parameters": {
                "operation": "send",
                "from": "={{ $env.TWILIO_PHONE_NUMBER }}",
                "to": "={{ $json.phone }}",
                "body": "Bitte senden Sie uns ein Foto Ihres Stromzählers.",
                "options": {"maxTries": 3, "waitBetweenTries": 2000},
            },
            "name": "Twilio - Send Error Photo",
            "type": "n8n-nodes-base.twilio",
            "typeVersion": 1,
        }
    )

    # 18. Twilio SMS - Complete
    nodes.append(
        {
            "parameters": {
                "operation": "send",
                "from": "={{ $env.TWILIO_PHONE_NUMBER }}",
                "to": "={{ $json.phone }}",
                "body": "Vielen Dank! Wir haben alle Informationen erhalten. Wir melden uns bald bei Ihnen.",
                "options": {"maxTries": 3, "waitBetweenTries": 2000},
            },
            "name": "Twilio - Send Complete",
            "type": "n8n-nodes-base.twilio",
            "typeVersion": 1,
        }
    )

    # 19. Respond - Webhook Complete
    nodes.append(
        {
            "parameters": {
                "respondWith": "text",
                "responseBody": "Nachricht verarbeitet.",
                "responseHeaders": {
                    "headerParameters": {
                        "parameters": [{"name": "Content-Type", "value": "text/plain"}]
                    }
                },
            },
            "name": "Respond - 3Q Complete",
            "type": "n8n-nodes-base.respondToWebhook",
            "typeVersion": 1,
        }
    )

    return nodes


def create_connections():
    connections = {}

    # From "Google Sheets - Lookup User" to "Code - Extract State"
    connections["Google Sheets - Lookup User"] = {
        "main": [[{"node": "Code - Extract State", "type": "main", "index": 0}]]
    }

    # From "Code - Extract State" to "Switch - State Router"
    connections["Code - Extract State"] = {
        "main": [[{"node": "Switch - State Router", "type": "main", "index": 0}]]
    }

    # Switch outputs (5 routes)
    connections["Switch - State Router"] = {
        "main": [
            [
                {"node": "IF - Is JA Response", "type": "main", "index": 0}
            ],  # Output 0: Empty/SMS_Sent
            [
                {"node": "Code - Validate PLZ", "type": "main", "index": 0}
            ],  # Output 1: Awaiting PLZ
            [
                {"node": "Code - Validate kWh", "type": "main", "index": 0}
            ],  # Output 2: Awaiting kWh
            [
                {"node": "Code - Validate Photo", "type": "main", "index": 0}
            ],  # Output 3: Awaiting Photo
            [
                {"node": "Respond - 3Q Complete", "type": "main", "index": 0}
            ],  # Output 4: Qualified Complete
        ]
    }

    # From "IF - Is JA Response" to "Google Sheets - Set Awaiting PLZ" (true) or error (false)
    connections["IF - Is JA Response"] = {
        "main": [
            [
                {"node": "Google Sheets - Set Awaiting PLZ", "type": "main", "index": 0}
            ],  # True
            [
                {"node": "Respond - Acknowledge", "type": "main", "index": 0}
            ],  # False (already exists)
        ]
    }

    # From "Code - Validate PLZ"
    connections["Code - Validate PLZ"] = {
        "main": [
            [
                {"node": "Google Sheets - Set Awaiting kWh", "type": "main", "index": 0}
            ],  # True - valid
            [
                {"node": "Twilio - Send Error PLZ", "type": "main", "index": 0}
            ],  # False - invalid
        ]
    }

    # From "Code - Validate kWh"
    connections["Code - Validate kWh"] = {
        "main": [
            [
                {
                    "node": "Google Sheets - Set Awaiting Photo",
                    "type": "main",
                    "index": 0,
                }
            ],  # True - valid
            [
                {"node": "Twilio - Send Error kWh", "type": "main", "index": 0}
            ],  # False - invalid
        ]
    }

    # From "Code - Validate Photo"
    connections["Code - Validate Photo"] = {
        "main": [
            [
                {
                    "node": "Google Sheets - Set Qualified Complete",
                    "type": "main",
                    "index": 0,
                }
            ],  # True - valid
            [
                {"node": "Twilio - Send Error Photo", "type": "main", "index": 0}
            ],  # False - invalid
        ]
    }

    # From state update nodes to SMS nodes
    connections["Google Sheets - Set Awaiting PLZ"] = {
        "main": [[{"node": "Twilio - Send Q1 (PLZ)", "type": "main", "index": 0}]]
    }

    connections["Google Sheets - Set Awaiting kWh"] = {
        "main": [[{"node": "Twilio - Send Q2 (kWh)", "type": "main", "index": 0}]]
    }

    connections["Google Sheets - Set Awaiting Photo"] = {
        "main": [[{"node": "Twilio - Send Q3 (Photo)", "type": "main", "index": 0}]]
    }

    connections["Google Sheets - Set Qualified Complete"] = {
        "main": [[{"node": "Twilio - Send Complete", "type": "main", "index": 0}]]
    }

    # From SMS nodes to Respond
    connections["Twilio - Send Q1 (PLZ)"] = {
        "main": [[{"node": "Respond - 3Q Complete", "type": "main", "index": 0}]]
    }

    connections["Twilio - Send Q2 (kWh)"] = {
        "main": [[{"node": "Respond - 3Q Complete", "type": "main", "index": 0}]]
    }

    connections["Twilio - Send Q3 (Photo)"] = {
        "main": [[{"node": "Respond - 3Q Complete", "type": "main", "index": 0}]]
    }

    connections["Twilio - Send Error PLZ"] = {
        "main": [[{"node": "Respond - 3Q Complete", "type": "main", "index": 0}]]
    }

    connections["Twilio - Send Error kWh"] = {
        "main": [[{"node": "Respond - 3Q Complete", "type": "main", "index": 0}]]
    }

    connections["Twilio - Send Error Photo"] = {
        "main": [[{"node": "Respond - 3Q Complete", "type": "main", "index": 0}]]
    }

    connections["Twilio - Send Complete"] = {
        "main": [[{"node": "Respond - 3Q Complete", "type": "main", "index": 0}]]
    }

    connections["Respond - 3Q Complete"] = {"main": []}

    return connections


def main():
    input_path = "/Users/avion/Documents.nosync/projects/vorzimmerdrache/workflows/sms-opt-in.json"
    output_path = "/Users/avion/Documents.nosync/projects/vorzimmerdrache/workflows/sms-opt-in-complete.json"

    with open(input_path, "r") as f:
        workflow = json.load(f)

    # Add new nodes
    new_nodes = create_3q_nodes()
    workflow["nodes"].extend(new_nodes)

    # Add new connections
    new_connections = create_connections()
    workflow["connections"].update(new_connections)

    # Modify existing connection from "IF - Validation Error" to insert Google Sheets Lookup
    # Find the validation error node and redirect to lookup
    for conn in workflow["connections"]["IF - Validation Error"]["main"]:
        if conn[0]["node"] == "IF - STOP Request":
            conn[0]["node"] = "Google Sheets - Lookup User"

    # Write output
    with open(output_path, "w") as f:
        json.dump(workflow, f, indent=2)

    print("Script created successfully")


if __name__ == "__main__":
    main()
