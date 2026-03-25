import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_models.dart';
import 'package:opencode_mobile_remote/src/features/chat/session_context_insights.dart';
import 'package:opencode_mobile_remote/src/features/settings/config_service.dart';

void main() {
  test('computes context metrics from the last assistant message with tokens', () {
    final messages = <ChatMessage>[
      ChatMessage(
        info: const ChatMessageInfo(
          id: 'msg_user_1',
          role: 'user',
        ),
        parts: const <ChatPart>[
          ChatPart(id: 'part_user_1', type: 'text', text: 'hello'),
        ],
      ),
      ChatMessage(
        info: const ChatMessageInfo(
          id: 'msg_assistant_1',
          role: 'assistant',
          providerId: 'openai',
          modelId: 'gpt-5.4',
          cost: 0.2,
          inputTokens: 24,
          outputTokens: 8,
          reasoningTokens: 2,
          cacheReadTokens: 4,
          cacheWriteTokens: 1,
        ),
        parts: const <ChatPart>[
          ChatPart(id: 'part_assistant_1', type: 'text', text: 'response'),
        ],
      ),
      ChatMessage(
        info: const ChatMessageInfo(
          id: 'msg_assistant_2',
          role: 'assistant',
          providerId: 'openai',
          modelId: 'gpt-5.4',
          cost: 0.3,
          inputTokens: 311,
          outputTokens: 373,
          reasoningTokens: 61,
          cacheReadTokens: 51200,
          cacheWriteTokens: 0,
        ),
        parts: const <ChatPart>[
          ChatPart(id: 'part_assistant_2', type: 'text', text: 'final'),
        ],
      ),
      ChatMessage(
        info: const ChatMessageInfo(
          id: 'msg_assistant_3',
          role: 'assistant',
          providerId: 'openai',
          modelId: 'gpt-5.4',
          cost: 0.1,
          inputTokens: 0,
          outputTokens: 0,
          reasoningTokens: 0,
          cacheReadTokens: 0,
          cacheWriteTokens: 0,
        ),
        parts: const <ChatPart>[
          ChatPart(id: 'part_assistant_3', type: 'text', text: 'noop'),
        ],
      ),
    ];

    final providerCatalog = ProviderCatalog.fromJson(<String, Object?>{
      'providers': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'openai',
          'name': 'OpenAI',
          'models': <String, Object?>{
            'gpt-5.4': <String, Object?>{
              'id': 'gpt-5.4',
              'name': 'GPT-5.4',
              'limit': <String, Object?>{'context': 1050000},
            },
          },
        },
      ],
    });

    final metrics = getSessionContextMetrics(
      messages: messages,
      providerCatalog: providerCatalog,
    );

    expect(metrics.totalCost, closeTo(0.6, 0.0001));
    expect(metrics.context, isNotNull);
    expect(metrics.context!.message.info.id, 'msg_assistant_2');
    expect(metrics.context!.providerLabel, 'OpenAI');
    expect(metrics.context!.modelLabel, 'GPT-5.4');
    expect(metrics.context!.contextLimit, 1050000);
    expect(metrics.context!.inputTokens, 311);
    expect(metrics.context!.outputTokens, 373);
    expect(metrics.context!.reasoningTokens, 61);
    expect(metrics.context!.cacheReadTokens, 51200);
    expect(metrics.context!.cacheWriteTokens, 0);
    expect(metrics.context!.totalTokens, 51945);
    expect(metrics.context!.usagePercent, 5);
  });

  test('estimates breakdown buckets using upstream token heuristics', () {
    final messages = <ChatMessage>[
      ChatMessage(
        info: const ChatMessageInfo(id: 'msg_user_1', role: 'user'),
        parts: const <ChatPart>[
          ChatPart(
            id: 'part_user_1',
            type: 'text',
            text: '01234567890123456789',
          ),
        ],
      ),
      ChatMessage(
        info: const ChatMessageInfo(id: 'msg_assistant_1', role: 'assistant'),
        parts: <ChatPart>[
          const ChatPart(
            id: 'part_assistant_text',
            type: 'text',
            text: 'hello world!',
          ),
          ChatPart(
            id: 'part_assistant_tool',
            type: 'tool',
            metadata: const <String, Object?>{
              'state': <String, Object?>{
                'status': 'completed',
                'input': <String, Object?>{'a': '1', 'b': '2'},
                'output': '12345678',
              },
            },
          ),
        ],
      ),
    ];

    final breakdown = estimateSessionContextBreakdown(
      messages: messages,
      inputTokens: 50,
      systemPrompt: '1234567890123456',
    );

    expect(
      breakdown.map((segment) => segment.key),
      <SessionContextBreakdownKey>[
        SessionContextBreakdownKey.system,
        SessionContextBreakdownKey.user,
        SessionContextBreakdownKey.assistant,
        SessionContextBreakdownKey.tool,
        SessionContextBreakdownKey.other,
      ],
    );
    expect(
      breakdown.map((segment) => segment.tokens),
      <int>[4, 5, 3, 10, 28],
    );
  });

  test('resolves visible system prompt before the revert point', () {
    final messages = <ChatMessage>[
      ChatMessage(
        info: const ChatMessageInfo(
          id: 'msg_user_1',
          role: 'user',
          systemPrompt: 'Keep answers short.',
        ),
        parts: const <ChatPart>[],
      ),
      ChatMessage(
        info: const ChatMessageInfo(
          id: 'msg_user_2',
          role: 'user',
          systemPrompt: 'Ignored prompt',
        ),
        parts: const <ChatPart>[],
      ),
    ];

    expect(
      resolveSessionSystemPrompt(
        messages: messages,
        revertMessageId: 'msg_user_2',
      ),
      'Keep answers short.',
    );
  });
}
