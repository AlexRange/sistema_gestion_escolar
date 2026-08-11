import 'package:excel/excel.dart';
//import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../data/models/student_model.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/grade_model.dart';

// Imports condicionales según plataforma
import 'excel_export_stub.dart'
    if (dart.library.html) 'excel_export_web.dart'
    if (dart.library.io) 'excel_export_mobile.dart';

class ExcelExportService {
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _fileFmt = DateFormat('yyyyMMdd_HHmmss');

  Future<void> exportAttendance({
    required String groupName,
    required List<StudentModel> students,
    required List<AttendanceModel> attendance,
  }) async {
    final excel = Excel.createExcel();
    // Usar la hoja por defecto y limpiarla
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;

    final dates = attendance
        .map((a) => DateTime(a.date.year, a.date.month, a.date.day))
        .toSet()
        .toList()
      ..sort();

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    // Título
    final titleCell = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value =
        TextCellValue('Registro de Asistencia — $groupName');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      backgroundColorHex: ExcelColor.fromHexString('#0D47A1'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    // Encabezados
    final headers = ['No.', 'Alumno', ...dates.map(_dateFmt.format), '%'];
    for (int c = 0; c < headers.length; c++) {
      final cell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = headerStyle;
    }

    // Datos de alumnos
    final sorted = [...students]
      ..sort((a, b) => a.listNumber.compareTo(b.listNumber));

    for (int r = 0; r < sorted.length; r++) {
      final student = sorted[r];
      final rowIdx = r + 2;

      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: 0, rowIndex: rowIdx))
          .value = IntCellValue(student.listNumber);
      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: 1, rowIndex: rowIdx))
          .value = TextCellValue(student.fullName);

      int presentCount = 0;
      for (int d = 0; d < dates.length; d++) {
        final att = attendance.firstWhere(
          (a) =>
              a.studentId == student.id &&
              a.date.year == dates[d].year &&
              a.date.month == dates[d].month &&
              a.date.day == dates[d].day,
          orElse: () => AttendanceModel(
            id: '',
            groupId: '',
            studentId: student.id,
            date: dates[d],
            status: AttendanceStatus.absent,
          ),
        );
        if (att.status == AttendanceStatus.present) presentCount++;
        final cell = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: d + 2, rowIndex: rowIdx));
        cell.value = TextCellValue(att.status.label);
        cell.cellStyle = CellStyle(
          fontColorHex:
              ExcelColor.fromHexString(_statusHex(att.status)),
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      final pct = dates.isEmpty
          ? 0.0
          : (presentCount / dates.length) * 100;
      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: dates.length + 2, rowIndex: rowIdx))
          .value = TextCellValue('${pct.toStringAsFixed(0)}%');
    }

    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 28);
    for (int d = 0; d < dates.length; d++) {
      sheet.setColumnWidth(d + 2, 14);
    }

    final bytes = excel.save()!;
    final filename =
        'Asistencia_${groupName}_${_fileFmt.format(DateTime.now())}.xlsx';
    await saveAndShareFile(bytes, filename);
  }

  Future<void> exportGrades({
    required String groupName,
    required List<StudentModel> students,
    required List<GradeModel> grades,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;

    final periods =
        grades.map((g) => g.periodName).toSet().toList()..sort();

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    // Título
    final titleCell = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value =
        TextCellValue('Registro de Calificaciones — $groupName');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      backgroundColorHex: ExcelColor.fromHexString('#0D47A1'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    // Encabezados
    final headers = ['No.', 'Alumno', ...periods, 'Promedio'];
    for (int c = 0; c < headers.length; c++) {
      final cell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = headerStyle;
    }

    // Datos
    final sorted = [...students]
      ..sort((a, b) => a.listNumber.compareTo(b.listNumber));

    for (int r = 0; r < sorted.length; r++) {
      final student = sorted[r];
      final rowIdx = r + 2;

      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: 0, rowIndex: rowIdx))
          .value = IntCellValue(student.listNumber);
      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: 1, rowIndex: rowIdx))
          .value = TextCellValue(student.fullName);

      final values = <double>[];
      for (int p = 0; p < periods.length; p++) {
        final grade = grades.firstWhere(
          (g) =>
              g.studentId == student.id &&
              g.periodName == periods[p],
          orElse: () => GradeModel(
            id: '',
            groupId: '',
            studentId: student.id,
            periodName: periods[p],
            value: -1,
            recordedAt: DateTime.now(),
          ),
        );
        final cell = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: p + 2, rowIndex: rowIdx));
        if (grade.value >= 0) {
          values.add(grade.value);
          cell.value = DoubleCellValue(grade.value);
          cell.cellStyle = CellStyle(
            fontColorHex:
                ExcelColor.fromHexString(_gradeHex(grade.value)),
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
        } else {
          cell.value = TextCellValue('—');
        }
      }

      // Al final del loop de alumnos, después de calcular values:
      final avg = values.isEmpty
          ? null
          : values.reduce((a, b) => a + b) / values.length;

      final avgCell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: periods.length + 2, rowIndex: rowIdx));

      if (avg != null) {
        // Escribir como texto formateado para garantizar que aparezca
        avgCell.value = TextCellValue(avg.toStringAsFixed(1));
        avgCell.cellStyle = CellStyle(
          bold: true,
          fontColorHex: ExcelColor.fromHexString(_gradeHex(avg)),
          horizontalAlign: HorizontalAlign.Center,
        );
      } else {
        avgCell.value = TextCellValue('—');
      }
    }

    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 28);
    for (int p = 0; p < periods.length; p++) {
      sheet.setColumnWidth(p + 2, 14);
    }

    final bytes = excel.save()!;
    final filename =
        'Calificaciones_${groupName}_${_fileFmt.format(DateTime.now())}.xlsx';
    await saveAndShareFile(bytes, filename);
  }
    Future<void> exportPartialSummary({
    required String groupName,
    required List<StudentModel> students,
    required List<Map<String, dynamic>> summaryData,
    // summaryData = lista de {studentId, partialName, att, act, eval, total}
  }) async {
    final excel = Excel.createExcel();
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    // Título
    final titleCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value =
        TextCellValue('Resumen de Calificaciones — $groupName');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      backgroundColorHex: ExcelColor.fromHexString('#0D47A1'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    // Obtener parciales únicos ordenados
    final partials = summaryData
        .map((d) => d['partialName'] as String)
        .toSet()
        .toList()
      ..sort();

    // Encabezados: No. | Alumno | Parcial1 | Parcial2 ... | Promedio Final
    final headers = ['No.', 'Alumno', ...partials, 'Promedio Final', 'Estado'];
    for (int c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = headerStyle;
    }

    // Filas de alumnos
    final sorted = [...students]
      ..sort((a, b) => a.listNumber.compareTo(b.listNumber));

    for (int r = 0; r < sorted.length; r++) {
      final student = sorted[r];
      final rowIdx = r + 2;

      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: 0, rowIndex: rowIdx))
          .value = IntCellValue(student.listNumber);
      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: 1, rowIndex: rowIdx))
          .value = TextCellValue(student.fullName);

      final partialTotals = <double>[];

      for (int p = 0; p < partials.length; p++) {
        final entry = summaryData.firstWhere(
          (d) =>
              d['studentId'] == student.id &&
              d['partialName'] == partials[p],
          orElse: () => {'total': -1.0},
        );
        final total = (entry['total'] as num?)?.toDouble() ?? -1;
        final cell = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: p + 2, rowIndex: rowIdx));

        if (total >= 0) {
          partialTotals.add(total);
          cell.value = TextCellValue(total.toStringAsFixed(1));
          cell.cellStyle = CellStyle(
            fontColorHex:
                ExcelColor.fromHexString(_gradeHex(total)),
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
        } else {
          cell.value = TextCellValue('—');
        }
      }

      // Promedio final del cuatrimestre
      final finalAvg = partialTotals.isEmpty
          ? null
          : partialTotals.reduce((a, b) => a + b) /
              partialTotals.length;

      final avgCell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: partials.length + 2, rowIndex: rowIdx));
      final statusCell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: partials.length + 3, rowIndex: rowIdx));

      if (finalAvg != null) {
        avgCell.value = TextCellValue(finalAvg.toStringAsFixed(1));
        avgCell.cellStyle = CellStyle(
          bold: true,
          fontColorHex:
              ExcelColor.fromHexString(_gradeHex(finalAvg)),
          horizontalAlign: HorizontalAlign.Center,
        );
        statusCell.value = TextCellValue(
            finalAvg >= 60 ? 'ACREDITADO' : 'NO ACREDITADO');
        statusCell.cellStyle = CellStyle(
          bold: true,
          fontColorHex: ExcelColor.fromHexString(
              finalAvg >= 60 ? '#2E7D32' : '#D32F2F'),
          horizontalAlign: HorizontalAlign.Center,
        );
      } else {
        avgCell.value = TextCellValue('—');
        statusCell.value = TextCellValue('—');
      }
    }

    // Anchos de columna
    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 28);
    for (int p = 0; p < partials.length; p++) {
      sheet.setColumnWidth(p + 2, 12);
    }
    sheet.setColumnWidth(partials.length + 2, 14);
    sheet.setColumnWidth(partials.length + 3, 16);

    final bytes = excel.save()!;
    await saveAndShareFile(
      bytes,
      'Calificaciones_${groupName}_${_fileFmt.format(DateTime.now())}.xlsx',
    );
  }

  String _statusHex(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:   return '#2E7D32';
      case AttendanceStatus.absent:    return '#D32F2F';
      case AttendanceStatus.late:      return '#E65100';
      case AttendanceStatus.justified: return '#0288D1';
    }
  }

  String _gradeHex(double v) {
    if (v >= 8) return '#2E7D32';
    if (v >= 6) return '#E65100';
    return '#D32F2F';
  }
  // ── Exportar TODOS los grupos en un solo libro: Asistencia ────────────
  Future<void> exportAllGroupsAttendance({
    required Map<String, List<StudentModel>> studentsByGroup,
    required Map<String, List<AttendanceModel>> attendanceByGroup,
    required Map<String, String> groupNames, // groupId → nombre
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.tables.keys.first;
    bool firstSheet = true;

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    for (final groupId in studentsByGroup.keys) {
      final students = studentsByGroup[groupId]!;
      final attendance = attendanceByGroup[groupId] ?? [];
      final groupName = groupNames[groupId] ?? groupId;

      // Nombre de hoja válido (máx 31 caracteres, sin caracteres especiales)
      final sheetName = _safeSheetName(groupName);

      late Sheet sheet;
      if (firstSheet) {
        excel.rename(defaultSheet, sheetName);
        sheet = excel[sheetName];
        firstSheet = false;
      } else {
        sheet = excel[sheetName];
      }

      final dates = attendance
          .map((a) => DateTime(a.date.year, a.date.month, a.date.day))
          .toSet()
          .toList()
        ..sort();

      // Título
      final titleCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      titleCell.value =
          TextCellValue('Registro de Asistencia — $groupName');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        backgroundColorHex: ExcelColor.fromHexString('#0D47A1'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );

      // Encabezados
      final headers = ['No.', 'Alumno', ...dates.map(_dateFmt.format), '%'];
      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }

      final sorted = [...students]
        ..sort((a, b) => a.listNumber.compareTo(b.listNumber));

      for (int r = 0; r < sorted.length; r++) {
        final student = sorted[r];
        final rowIdx = r + 2;

        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: rowIdx))
            .value = IntCellValue(student.listNumber);
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: rowIdx))
            .value = TextCellValue(student.fullName);

        int presentCount = 0;
        for (int d = 0; d < dates.length; d++) {
          final att = attendance.firstWhere(
            (a) =>
                a.studentId == student.id &&
                a.date.year == dates[d].year &&
                a.date.month == dates[d].month &&
                a.date.day == dates[d].day,
            orElse: () => AttendanceModel(
              id: '',
              groupId: '',
              studentId: student.id,
              date: dates[d],
              status: AttendanceStatus.absent,
            ),
          );
          if (att.status == AttendanceStatus.present) presentCount++;
          final cell = sheet.cell(CellIndex.indexByColumnRow(
              columnIndex: d + 2, rowIndex: rowIdx));
          cell.value = TextCellValue(att.status.label);
          cell.cellStyle = CellStyle(
            fontColorHex:
                ExcelColor.fromHexString(_statusHex(att.status)),
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
        }

        final pct =
            dates.isEmpty ? 0.0 : (presentCount / dates.length) * 100;
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: dates.length + 2, rowIndex: rowIdx))
            .value = TextCellValue('${pct.toStringAsFixed(0)}%');
      }

      sheet.setColumnWidth(0, 6);
      sheet.setColumnWidth(1, 28);
      for (int d = 0; d < dates.length; d++) {
        sheet.setColumnWidth(d + 2, 14);
      }
    }

    final bytes = excel.save()!;
    await saveAndShareFile(
      bytes,
      'Asistencia_TodosGrupos_${_fileFmt.format(DateTime.now())}.xlsx',
    );
  }

  // ── Exportar TODOS los grupos en un solo libro: Calificaciones ────────
  Future<void> exportAllGroupsSummary({
    required Map<String, List<StudentModel>> studentsByGroup,
    required Map<String, List<Map<String, dynamic>>> summaryByGroup,
    required Map<String, String> groupNames,
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.tables.keys.first;
    bool firstSheet = true;

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    for (final groupId in studentsByGroup.keys) {
      final students = studentsByGroup[groupId]!;
      final summaryData = summaryByGroup[groupId] ?? [];
      final groupName = groupNames[groupId] ?? groupId;
      final sheetName = _safeSheetName(groupName);

      late Sheet sheet;
      if (firstSheet) {
        excel.rename(defaultSheet, sheetName);
        sheet = excel[sheetName];
        firstSheet = false;
      } else {
        sheet = excel[sheetName];
      }

      final titleCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      titleCell.value =
          TextCellValue('Resumen de Calificaciones — $groupName');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        backgroundColorHex: ExcelColor.fromHexString('#0D47A1'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );

      final partials = summaryData
          .map((d) => d['partialName'] as String)
          .toSet()
          .toList()
        ..sort();

      final headers = [
        'No.',
        'Alumno',
        ...partials,
        'Promedio Final',
        'Estado'
      ];
      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }

      final sorted = [...students]
        ..sort((a, b) => a.listNumber.compareTo(b.listNumber));

      for (int r = 0; r < sorted.length; r++) {
        final student = sorted[r];
        final rowIdx = r + 2;

        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: rowIdx))
            .value = IntCellValue(student.listNumber);
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: rowIdx))
            .value = TextCellValue(student.fullName);

        final partialTotals = <double>[];

        for (int p = 0; p < partials.length; p++) {
          final entry = summaryData.firstWhere(
            (d) =>
                d['studentId'] == student.id &&
                d['partialName'] == partials[p],
            orElse: () => {'total': -1.0},
          );
          final total = (entry['total'] as num?)?.toDouble() ?? -1;
          final cell = sheet.cell(CellIndex.indexByColumnRow(
              columnIndex: p + 2, rowIndex: rowIdx));

          if (total >= 0) {
            partialTotals.add(total);
            cell.value = TextCellValue(total.toStringAsFixed(1));
            cell.cellStyle = CellStyle(
              fontColorHex:
                  ExcelColor.fromHexString(_gradeHex(total)),
              bold: true,
              horizontalAlign: HorizontalAlign.Center,
            );
          } else {
            cell.value = TextCellValue('—');
          }
        }

        final finalAvg = partialTotals.isEmpty
            ? null
            : partialTotals.reduce((a, b) => a + b) /
                partialTotals.length;

        final avgCell = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: partials.length + 2, rowIndex: rowIdx));
        final statusCell = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: partials.length + 3, rowIndex: rowIdx));

        if (finalAvg != null) {
          avgCell.value = TextCellValue(finalAvg.toStringAsFixed(1));
          avgCell.cellStyle = CellStyle(
            bold: true,
            fontColorHex:
                ExcelColor.fromHexString(_gradeHex(finalAvg)),
            horizontalAlign: HorizontalAlign.Center,
          );
          statusCell.value = TextCellValue(
              finalAvg >= 60 ? 'ACREDITADO' : 'NO ACREDITADO');
          statusCell.cellStyle = CellStyle(
            bold: true,
            fontColorHex: ExcelColor.fromHexString(
                finalAvg >= 60 ? '#2E7D32' : '#D32F2F'),
            horizontalAlign: HorizontalAlign.Center,
          );
        } else {
          avgCell.value = TextCellValue('—');
          statusCell.value = TextCellValue('—');
        }
      }

      sheet.setColumnWidth(0, 6);
      sheet.setColumnWidth(1, 28);
      for (int p = 0; p < partials.length; p++) {
        sheet.setColumnWidth(p + 2, 12);
      }
      sheet.setColumnWidth(partials.length + 2, 14);
      sheet.setColumnWidth(partials.length + 3, 16);
    }

    final bytes = excel.save()!;
    await saveAndShareFile(
      bytes,
      'Calificaciones_TodosGrupos_${_fileFmt.format(DateTime.now())}.xlsx',
    );
  }

  // Nombre de hoja válido para Excel (máx 31 chars, sin: \ / ? * [ ] :)
  String _safeSheetName(String name) {
    var safe = name.replaceAll(RegExp(r'[\\/?*\[\]:]'), '');
    if (safe.length > 31) safe = safe.substring(0, 31);
    if (safe.isEmpty) safe = 'Grupo';
    return safe;
  }
}
