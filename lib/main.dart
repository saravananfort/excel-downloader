import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clipboard Table Downloader',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: TablePage(),
    );
  }
}

class TablePage extends StatefulWidget {
  @override
  _TablePageState createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  List<List<String>> tableData = [];
  int fileNameColumn = 0;
  int urlColumn = 1;
  bool downloading = false;

  late MyDataGridSource dataGridSource;

  String? downloadFolderPath; // <-- selected folder

  @override
  void initState() {
    super.initState();
    dataGridSource = MyDataGridSource(tableData: tableData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Clipboard Table Downloader")),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: ElevatedButton(
                    onPressed: pasteClipboard,
                    child: Text("Paste Table from Clipboard"),
                  ),
                ),
                Expanded(
                  child: SfDataGrid(
                    source: dataGridSource,
                    allowEditing: true,
                    columnWidthMode: ColumnWidthMode.fill,
                    columns: tableData.isNotEmpty
                        ? List.generate(
                            tableData[0].length,
                            (index) => GridColumn(
                              columnName: 'col$index',
                              label: Container(
                                padding: EdgeInsets.all(8),
                                alignment: Alignment.center,
                                child: Text('Col $index'),
                              ),
                            ),
                          )
                        : [],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 220,
            color: Colors.grey[200],
            padding: EdgeInsets.all(8),
            child: Column(
              children: [
                Text("Select Filename Column"),
                DropdownButton<int>(
                  value: fileNameColumn,
                  items: tableData.isNotEmpty
                      ? List.generate(
                          tableData[0].length,
                          (i) =>
                              DropdownMenuItem(child: Text("Col $i"), value: i),
                        )
                      : [],
                  onChanged: (val) => setState(() => fileNameColumn = val!),
                ),
                SizedBox(height: 10),
                Text("Select URL Column"),
                DropdownButton<int>(
                  value: urlColumn,
                  items: tableData.isNotEmpty
                      ? List.generate(
                          tableData[0].length,
                          (i) =>
                              DropdownMenuItem(child: Text("Col $i"), value: i),
                        )
                      : [],
                  onChanged: (val) => setState(() => urlColumn = val!),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: selectFolder,
                  child: Text(
                    downloadFolderPath != null
                        ? "Folder: ${downloadFolderPath!.split('/').last}"
                        : "Select Download Folder",
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed:
                      downloading ||
                          tableData.isEmpty ||
                          downloadFolderPath == null
                      ? null
                      : downloadAll,
                  child: Text(downloading ? "Downloading..." : "Download All"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> pasteClipboard() async {
    ClipboardData? data = await Clipboard.getData('text/plain');
    if (data == null || data.text == null) return;

    List<String> rows = data.text!.split('\n');
    List<List<String>> parsed = [];
    for (var row in rows) {
      if (row.trim().isEmpty) continue;
      parsed.add(row.split('\t'));
    }

    setState(() {
      tableData = parsed;
      fileNameColumn = 0;
      urlColumn = tableData[0].length > 1 ? 1 : 0;
      dataGridSource = MyDataGridSource(tableData: tableData);
    });
  }

  Future<void> selectFolder() async {
    String? path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      setState(() => downloadFolderPath = path);
    }
  }

   String convertDriveShareToDirectLink(String shareLink) {
    final fileIdRegEx = RegExp(r'/d/([a-zA-Z0-9_-]+)');
    final match = fileIdRegEx.firstMatch(shareLink);

    if (match != null && match.groupCount >= 1) {
      final fileId = match.group(1);
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    } else {
      throw FormatException('Invalid Google Drive share link');
    }
  }

  Future<void> downloadAll() async {
    if (downloadFolderPath == null) return;

    setState(() => downloading = true);
    Dio dio = Dio();

    for (var row in tableData) {
      try {
        String fileName = row[fileNameColumn].replaceAll(' ', '_');
        String url = row[urlColumn];
        if (!url.startsWith('http')) continue;

        String path = "$downloadFolderPath/${fileName.toLowerCase()}.pdf";

        final isGoogleDrive = (url.contains('drive.google.com'));
        
        url =
            isGoogleDrive ? convertDriveShareToDirectLink(url) : url;

        await dio.download(url, path);
        print("Downloaded $fileName → $path");
      } catch (e) {
        print("Failed: $e");
      }
    }

    setState(() => downloading = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("All downloads completed!")));
  }
}

class MyDataGridSource extends DataGridSource {
  List<DataGridRow> _dataGridRows = [];

  MyDataGridSource({required List<List<String>> tableData}) {
    _dataGridRows = tableData
        .map(
          (row) => DataGridRow(
            cells: row
                .map(
                  (cell) => DataGridCell<String>(columnName: '', value: cell),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row
          .getCells()
          .map(
            (cell) => Container(
              padding: EdgeInsets.all(8),
              alignment: Alignment.center,
              child: Text(cell.value),
            ),
          )
          .toList(),
    );
  }
}
