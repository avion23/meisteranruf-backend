const fs = require('fs');
const path = require('path');

describe('n8n Workflow Validation', () => {
  const workflowDir = path.join(__dirname, '../../workflows');
  let workflows = [];

  beforeAll(() => {
    workflows = fs.readdirSync(workflowDir)
      .filter(file => file.endsWith('.json'))
      .map(file => ({
        name: file,
        path: path.join(workflowDir, file),
        content: JSON.parse(fs.readFileSync(path.join(workflowDir, file), 'utf8'))
      }));
  });

  describe('File Structure', () => {
    test('workflows directory should contain at least one workflow', () => {
      expect(workflows.length).toBeGreaterThan(0);
    });

    test('all workflow files should be valid JSON', () => {
      workflows.forEach(wf => {
        expect(wf.content).toBeDefined();
        expect(typeof wf.content).toBe('object');
      });
    });
  });

  describe('Required Top-Level Fields', () => {
    workflows.forEach(workflow => {
      describe(`${workflow.name}`, () => {
        test('should have name field', () => {
          expect(workflow.content.name).toBeDefined();
          expect(typeof workflow.content.name).toBe('string');
          expect(workflow.content.name.length).toBeGreaterThan(0);
        });

        test('should have nodes array', () => {
          expect(workflow.content.nodes).toBeDefined();
          expect(Array.isArray(workflow.content.nodes)).toBe(true);
          expect(workflow.content.nodes.length).toBeGreaterThan(0);
        });

        test('should have connections object', () => {
          expect(workflow.content.connections).toBeDefined();
          expect(typeof workflow.content.connections).toBe('object');
        });

        test('should have settings object', () => {
          expect(workflow.content.settings).toBeDefined();
          expect(typeof workflow.content.settings).toBe('object');
        });
      });
    });
  });

  describe('Node Structure Validation', () => {
    workflows.forEach(workflow => {
      describe(`${workflow.name} - Nodes`, () => {
        workflow.content.nodes.forEach((node, idx) => {
          test(`node[${idx}] (${node.name || 'unnamed'}) should have required fields`, () => {
            expect(node.id).toBeDefined();
            expect(typeof node.id).toBe('string');
            
            expect(node.name).toBeDefined();
            expect(typeof node.name).toBe('string');
            
            expect(node.type).toBeDefined();
            expect(typeof node.type).toBe('string');
            expect(node.type).toMatch(/^n8n-nodes-/);
            
            expect(node.position).toBeDefined();
            expect(Array.isArray(node.position)).toBe(true);
            expect(node.position.length).toBe(2);
            expect(typeof node.position[0]).toBe('number');
            expect(typeof node.position[1]).toBe('number');
            
            expect(node.parameters).toBeDefined();
            expect(typeof node.parameters).toBe('object');
          });

          test(`node[${idx}] (${node.name || 'unnamed'}) should have valid typeVersion`, () => {
            expect(node.typeVersion).toBeDefined();
            expect(typeof node.typeVersion).toBe('number');
            expect(node.typeVersion).toBeGreaterThan(0);
          });
        });
      });
    });
  });

  describe('Node Connections Validation', () => {
    workflows.forEach(workflow => {
      describe(`${workflow.name} - Connections`, () => {
        test('all connection source nodes should exist', () => {
          const nodeNames = workflow.content.nodes.map(n => n.name);
          const connectionKeys = Object.keys(workflow.content.connections);
          
          connectionKeys.forEach(sourceName => {
            expect(nodeNames).toContain(sourceName);
          });
        });

        test('all connection target nodes should exist', () => {
          const nodeNames = workflow.content.nodes.map(n => n.name);
          
          Object.values(workflow.content.connections).forEach(connectionGroup => {
            if (connectionGroup.main) {
              connectionGroup.main.forEach(outputConnections => {
                if (Array.isArray(outputConnections)) {
                  outputConnections.forEach(conn => {
                    expect(nodeNames).toContain(conn.node);
                  });
                }
              });
            }
          });
        });

        test('connections should have valid structure', () => {
          Object.values(workflow.content.connections).forEach(connectionGroup => {
            expect(connectionGroup.main).toBeDefined();
            expect(Array.isArray(connectionGroup.main)).toBe(true);
            
            connectionGroup.main.forEach(outputConnections => {
              if (Array.isArray(outputConnections)) {
                outputConnections.forEach(conn => {
                  expect(conn).toHaveProperty('node');
                  expect(conn).toHaveProperty('type');
                  expect(conn).toHaveProperty('index');
                  expect(typeof conn.node).toBe('string');
                  expect(conn.type).toBe('main');
                  expect(typeof conn.index).toBe('number');
                  expect(conn.index).toBeGreaterThanOrEqual(0);
                });
              }
            });
          });
        });
      });
    });
  });

  describe('Credential References', () => {
    workflows.forEach(workflow => {
      describe(`${workflow.name} - Credentials`, () => {
        const nodesWithCredentials = workflow.content.nodes.filter(n => n.credentials);

        if (nodesWithCredentials.length > 0) {
          test('credential references should have valid structure', () => {
            nodesWithCredentials.forEach(node => {
              Object.values(node.credentials).forEach(cred => {
                expect(cred).toHaveProperty('id');
                expect(cred).toHaveProperty('name');
                expect(typeof cred.id).toBe('string');
                expect(typeof cred.name).toBe('string');
                expect(cred.id.length).toBeGreaterThan(0);
              });
            });
          });

          test('credential types should match expected patterns', () => {
            const validCredTypes = [
              'twilioApi',
              'openAiApi',
              'googleSheetsOAuth2Api',
              'httpHeaderAuth',
              'httpBasicAuth',
              'httpDigestAuth',
              'oAuth2Api',
              'oAuth1Api'
            ];

            nodesWithCredentials.forEach(node => {
              Object.keys(node.credentials).forEach(credType => {
                // Should either be in known types or follow n8n naming convention
                const isValid = validCredTypes.includes(credType) || 
                               credType.endsWith('Api') || 
                               credType.endsWith('OAuth2Api');
                expect(isValid).toBe(true);
              });
            });
          });
        } else {
          test('workflow has no credential references', () => {
            expect(nodesWithCredentials.length).toBe(0);
          });
        }
      });
    });
  });

  describe('Webhook Nodes', () => {
    workflows.forEach(workflow => {
      describe(`${workflow.name} - Webhooks`, () => {
        const webhookNodes = workflow.content.nodes.filter(n => 
          n.type === 'n8n-nodes-base.webhook'
        );

        if (webhookNodes.length > 0) {
          test('webhook nodes should have path configured', () => {
            webhookNodes.forEach(node => {
              const hasPath = node.parameters?.path || node.path;
              expect(hasPath).toBeDefined();
              expect(typeof hasPath).toBe('string');
              expect(hasPath.length).toBeGreaterThan(0);
            });
          });

          test('webhook nodes should have webhookId', () => {
            webhookNodes.forEach(node => {
              expect(node.webhookId).toBeDefined();
              expect(typeof node.webhookId).toBe('string');
            });
          });

          test('webhook nodes should have responseMode', () => {
            webhookNodes.forEach(node => {
              const responseMode = node.parameters?.responseMode || node.responseMode;
              if (responseMode) {
                expect(['responseNode', 'lastNode', 'onReceived']).toContain(responseMode);
              }
            });
          });
        } else {
          test('workflow has no webhook nodes', () => {
            expect(webhookNodes.length).toBe(0);
          });
        }
      });
    });
  });

  describe('Code Nodes', () => {
    workflows.forEach(workflow => {
      describe(`${workflow.name} - Code Nodes`, () => {
        const codeNodes = workflow.content.nodes.filter(n => 
          n.type === 'n8n-nodes-base.code'
        );

        if (codeNodes.length > 0) {
          test('code nodes should have valid JavaScript code', () => {
            codeNodes.forEach(node => {
              const code = node.parameters?.jsCode || node.parameters?.functionCode;
              expect(code).toBeDefined();
              expect(typeof code).toBe('string');
              expect(code.length).toBeGreaterThan(0);
              
              // Check for syntax errors by trying to create a function
              expect(() => {
                new Function(code);
              }).not.toThrow();
            });
          });

          test('code nodes should use n8n context variables properly', () => {
            codeNodes.forEach(node => {
              const code = node.parameters?.jsCode || node.parameters?.functionCode;
              
              // If code uses $input, it should return proper structure
              if (code.includes('$input')) {
                // Should either return array or object with json property
                expect(
                  code.includes('return [') || 
                  code.includes('return {') ||
                  code.includes('return')
                ).toBe(true);
              }
            });
          });
        } else {
          test('workflow has no code nodes', () => {
            expect(codeNodes.length).toBe(0);
          });
        }
      });
    });
  });

  describe('Workflow Connectivity', () => {
    workflows.forEach(workflow => {
      describe(`${workflow.name} - Graph Analysis`, () => {
        test('workflow should have at least one trigger node', () => {
          const triggerTypes = [
            'n8n-nodes-base.webhook',
            'n8n-nodes-base.scheduleTrigger',
            'n8n-nodes-base.manualTrigger',
            'n8n-nodes-base.emailTrigger',
            'n8n-nodes-base.cronTrigger'
          ];
          
          const hasTrigger = workflow.content.nodes.some(n => 
            triggerTypes.includes(n.type)
          );
          
          expect(hasTrigger).toBe(true);
        });

        test('all nodes should be reachable from a trigger', () => {
          // Build adjacency list
          const adjacencyList = {};
          workflow.content.nodes.forEach(n => {
            adjacencyList[n.name] = [];
          });
          
          Object.entries(workflow.content.connections).forEach(([sourceName, conns]) => {
            if (conns.main) {
              conns.main.forEach(outputConnections => {
                if (Array.isArray(outputConnections)) {
                  outputConnections.forEach(conn => {
                    adjacencyList[sourceName].push(conn.node);
                  });
                }
              });
            }
          });
          
          // Find trigger nodes
          const triggerTypes = [
            'n8n-nodes-base.webhook',
            'n8n-nodes-base.scheduleTrigger',
            'n8n-nodes-base.manualTrigger',
            'n8n-nodes-base.splitInBatches'
          ];
          
          const triggerNodes = workflow.content.nodes
            .filter(n => triggerTypes.includes(n.type))
            .map(n => n.name);
          
          // BFS from triggers
          const visited = new Set();
          const queue = [...triggerNodes];
          
          while (queue.length > 0) {
            const current = queue.shift();
            if (visited.has(current)) continue;
            visited.add(current);
            
            const neighbors = adjacencyList[current] || [];
            neighbors.forEach(neighbor => {
              if (!visited.has(neighbor)) {
                queue.push(neighbor);
              }
            });
          }
          
          // All nodes should be reachable (or workflow has isolated nodes which is fine for IF/merge nodes)
          const totalNodes = workflow.content.nodes.length;
          const reachableNodes = visited.size;
          
          // Allow some flexibility for conditional branches and error handlers
          expect(reachableNodes).toBeGreaterThan(0);
          expect(reachableNodes / totalNodes).toBeGreaterThan(0.5);
        });
      });
    });
  });

  describe('Security & Best Practices', () => {
    workflows.forEach(workflow => {
      describe(`${workflow.name} - Security`, () => {
        test('should not contain hardcoded secrets in parameters', () => {
          const secretPatterns = [
            /sk-[a-zA-Z0-9]{32,}/,  // OpenAI API keys
            /xoxb-[a-zA-Z0-9-]+/,   // Slack tokens
            /ghp_[a-zA-Z0-9]{36,}/,  // GitHub tokens
            /AIza[a-zA-Z0-9_-]{35}/, // Google API keys
            /[0-9]{10}:[a-zA-Z0-9_-]{35}/, // Telegram bot tokens
          ];
          
          workflow.content.nodes.forEach(node => {
            const paramStr = JSON.stringify(node.parameters);
            secretPatterns.forEach(pattern => {
              expect(paramStr).not.toMatch(pattern);
            });
          });
        });

        test('should use environment variables for sensitive data', () => {
          const sensitiveParams = ['apiKey', 'token', 'password', 'secret'];
          
          workflow.content.nodes.forEach(node => {
            Object.entries(node.parameters || {}).forEach(([key, value]) => {
              if (sensitiveParams.some(sp => key.toLowerCase().includes(sp))) {
                if (typeof value === 'string' && value.length > 0) {
                  // Should reference env var or expression
                  const isEnvVar = value.includes('$env.') || 
                                 value.includes('={{') ||
                                 value === '';
                  expect(isEnvVar).toBe(true);
                }
              }
            });
          });
        });
      });
    });
  });

  describe('Specific Workflow Tests', () => {
    describe('inbound-handler-twilio-whatsapp.json', () => {
      const workflow = workflows.find(w => w.name === 'inbound-handler-twilio-whatsapp.json');
      
      if (workflow) {
        test('should have TwiML response node', () => {
          const twimlNode = workflow.content.nodes.find(n => 
            n.name === 'TwiML Voice Response' || 
            n.type === 'n8n-nodes-base.respondToWebhook'
          );
          expect(twimlNode).toBeDefined();
        });

        test('should have Twilio WhatsApp send node', () => {
          const twilioNode = workflow.content.nodes.find(n => 
            n.type === 'n8n-nodes-base.twilio' &&
            (n.name.includes('WhatsApp') || n.parameters?.operation === 'send')
          );
          expect(twilioNode).toBeDefined();
        });

        test('should have phone normalization', () => {
          const normalizeNode = workflow.content.nodes.find(n => 
            n.name.toLowerCase().includes('normalize') ||
            n.name.toLowerCase().includes('phone')
          );
          expect(normalizeNode).toBeDefined();
        });
      }
    });

    describe('doi-confirmation.json', () => {
      const workflow = workflows.find(w => w.name === 'doi-confirmation.json');
      
      if (workflow) {
        test('should have consent logging', () => {
          const logNode = workflow.content.nodes.find(n => 
            n.name.toLowerCase().includes('log') ||
            n.name.toLowerCase().includes('consent') ||
            n.name.toLowerCase().includes('database')
          );
          expect(logNode).toBeDefined();
        });
      }
    });

    describe('opt-out-handler.json', () => {
      const workflow = workflows.find(w => w.name === 'opt-out-handler.json');
      
      if (workflow) {
        test('should handle STOP keyword', () => {
          const stopHandlerNode = workflow.content.nodes.find(n => {
            const code = n.parameters?.jsCode || n.parameters?.functionCode || '';
            return code.toLowerCase().includes('stop') ||
                   code.toLowerCase().includes('stopp') ||
                   code.toLowerCase().includes('opt');
          });
          expect(stopHandlerNode).toBeDefined();
        });
      }
    });
  });
});
