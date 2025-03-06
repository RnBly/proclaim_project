// lib/services/excel_service.dart
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode

/// assets/script.xlsx 파일을 로드해서 Excel 객체를 반환합니다.
Future<Excel?> loadExcel() async {
  try {
    if (kDebugMode) {
      print("🔍 [excel_service] loadExcel() called...");
    }
    ByteData data = await rootBundle.load("assets/script.xlsx");
    var bytes = data.buffer.asUint8List();
    var excel = Excel.decodeBytes(bytes);
    if (kDebugMode) {
      print("✅ [excel_service] script.xlsx 로드 성공, sheet 수: ${excel.tables.keys.length}");
    }
    return excel;
  } catch (e) {
    if (kDebugMode) {
      print("❌ [excel_service] Excel 파일 로딩 오류: $e");
    }
    return null;
  }
}

/// 지정한 시트의 모든 행 데이터를 문자열 리스트의 리스트로 반환합니다.
Future<List<List<String>>> readSheetData(String sheetName) async {
  var excel = await loadExcel();
  if (excel == null) {
    if (kDebugMode) {
      print("⚠️ [excel_service] readSheetData($sheetName) - excel is null, returning empty list");
    }
    return [];
  }
  Sheet? sheet = excel[sheetName];
  if (sheet == null) {
    if (kDebugMode) {
      print("⚠️ [excel_service] readSheetData($sheetName) - sheet not found, returning empty list");
    }
    return [];
  }
  List<List<String>> rows = [];
  for (var rowIndex = 0; rowIndex < sheet.maxRows; rowIndex++) {
    List<Data?> row = sheet.row(rowIndex);
    List<String> values = row.map((cell) => cell?.value?.toString() ?? "").toList();
    rows.add(values);
  }
  if (kDebugMode) {
    print("✅ [excel_service] readSheetData($sheetName) - total rows read: ${rows.length}");
  }
  return rows;
}

/// 첫 번째 행을 헤더로 하여 데이터를 Map 리스트로 파싱합니다.
Future<List<Map<String, dynamic>>> readSheetDataAsMaps(String sheetName) async {
  final rows = await readSheetData(sheetName);
  List<Map<String, dynamic>> data = [];
  if (rows.isNotEmpty) {
    List<String> headers = rows.first;
    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.isEmpty) continue;
      Map<String, dynamic> map = {};
      for (int j = 0; j < headers.length && j < row.length; j++) {
        map[headers[j]] = row[j];
      }
      data.add(map);
    }
  }
  if (kDebugMode) {
    print("✅ [excel_service] readSheetDataAsMaps($sheetName) - total mapped rows: ${data.length}");
  }
  return data;
}

/// 선택한 날짜(월, 일)와 일치하는 행 데이터를 반환합니다.
/// 연도는 무시하고 month/day만 비교합니다.
Future<List<Map<String, dynamic>>> fetchTodayBibleRows(
    String sheetName, DateTime selectedDate) async {
  final rows = await readSheetDataAsMaps(sheetName);
  int selMonth = selectedDate.month;
  int selDay = selectedDate.day;
  List<Map<String, dynamic>> results = [];
  if (kDebugMode) {
    print("🔍 [excel_service] fetchTodayBibleRows($sheetName), selMonth=$selMonth, selDay=$selDay, totalRows=${rows.length}");
  }
  for (var row in rows) {
    if (row.containsKey("Date") && row["Date"] is String) {
      String dateString = row["Date"];
      List<String> parts = dateString.split("-");
      if (parts.length == 3) {
        int month = int.tryParse(parts[1]) ?? 0;
        int day = int.tryParse(parts[2]) ?? 0;
        if (month == selMonth && day == selDay) {
          results.add(row);
        }
      } else if (parts.length == 2) {
        int month = int.tryParse(parts[0]) ?? 0;
        int day = int.tryParse(parts[1]) ?? 0;
        if (month == selMonth && day == selDay) {
          results.add(row);
        }
      }
    }
  }
  if (kDebugMode) {
    print("✅ [excel_service] fetchTodayBibleRows($sheetName) - found ${results.length} matched rows");
    for (var r in results) {
      print("   -> $r");
    }
  }
  return results;
}
