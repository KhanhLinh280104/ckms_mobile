import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../services/api_service.dart';

class AiAnalysisResponse {
  final List<String> highlights;
  final List<String> risks;
  final List<String> recommendations;
  final String rawAnalysis;

  AiAnalysisResponse({
    required this.highlights,
    required this.risks,
    required this.recommendations,
    required this.rawAnalysis,
  });

  factory AiAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return AiAnalysisResponse(
      highlights: (json['highlights'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      risks: (json['risks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rawAnalysis: json['rawAnalysis']?.toString() ?? '',
    );
  }
}

class AiChatResponse {
  final String answer;
  final String modelUsed;

  AiChatResponse({required this.answer, required this.modelUsed});

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    return AiChatResponse(
      answer: json['answer']?.toString() ?? 'Không có phản hồi từ AI.',
      modelUsed: json['modelUsed']?.toString() ?? 'qwen2.5:3b',
    );
  }
}

class AiChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final String timestamp;

  AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

class AiReportService {
  static Future<AiAnalysisResponse> analyzeExecutiveCockpit() async {
    final rawData = await ApiService.analyzeAiExecutiveCockpit();
    if (rawData == null) {
      throw Exception('Không nhận được dữ liệu chuẩn đoán từ máy chủ.');
    }
    return AiAnalysisResponse.fromJson(rawData);
  }

  static Future<AiChatResponse> chatWithExecutiveData({
    required String question,
    String? chatHistory,
  }) async {
    final rawData = await ApiService.chatAiExecutiveData(
      question: question,
      chatHistory: chatHistory,
    );
    if (rawData == null) {
      throw Exception('Không nhận được câu trả lời từ AI.');
    }
    return AiChatResponse.fromJson(rawData);
  }
}
