import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
//import '../../data/models/student_model.dart';

class StudentImportData {
  final int listNumber;
  final String firstName;
  final String lastName;
  final String? matricula;

  const StudentImportData({
    required this.listNumber,
    required this.firstName,
    required this.lastName,
    this.matricula,
  });
}

class ExcelImportService {
  Future<List<StudentImportData>?> pickAndParse() async {
    // 1. Abrir selector de archivos
  final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return null; // Usuario canceló
    }

    // 2. Parsear Excel
    final bytes = result.files.single.bytes!;
    final excel = Excel.decodeBytes(bytes);
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;

    final students = <StudentImportData>[];

    // 3. Leer filas (saltar fila 0 si es encabezado)
    for (int i = 0; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;

      // Detectar si es fila de encabezado
      final firstCell = _cellToString(row[0]).toLowerCase();
      if (firstCell == 'no.' ||
          firstCell == 'num' ||
          firstCell == 'número' ||
          firstCell == 'no') continue;

      final listNum = _cellToInt(row.isNotEmpty ? row[0] : null);
      final col1 = row.length > 1 ? _cellToString(row[1]) : '';
      final col2 = row.length > 2 ? _cellToString(row[2]) : '';
      final col3 = row.length > 3 ? _cellToString(row[3]) : null;

      // Saltar filas vacías
      if (col1.isEmpty && col2.isEmpty) continue;

      students.add(StudentImportData(
        listNumber: listNum ?? (students.length + 1),
        firstName: col2.isNotEmpty ? col2 : col1,
        lastName: col2.isNotEmpty ? col1 : '',
        matricula: col3?.isNotEmpty == true ? col3 : null,
      ));
    }

    return students;
  }

String _cellToString(Data? cell) {
  if (cell == null) return '';
  final v = cell.value;
  if (v == null) return '';
  if (v is IntCellValue) return v.value.toString();
  if (v is DoubleCellValue) return v.value.toString();
  if (v is BoolCellValue) return v.value.toString();
  // Para TextCellValue y cualquier otro tipo, usar toString() del objeto
  final str = v.toString();
  // toString() de TextCellValue produce algo como "TextCellValue(TextSpan(...))"
  // extraemos solo el contenido interno
  final match = RegExp(r'"([^"]*)"').firstMatch(str);
  return match?.group(1)?.trim() ?? str.trim();
}

int? _cellToInt(Data? cell) {
  if (cell == null) return null;
  final v = cell.value;
  if (v == null) return null;
  if (v is IntCellValue) return v.value;
  if (v is DoubleCellValue) return v.value.toInt();
  return int.tryParse(_cellToString(cell).trim());
}
}
