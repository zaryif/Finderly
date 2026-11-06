import 'package:flutter_test/flutter_test.dart';
import 'package:finderly/models/folder_model.dart';
import 'package:finderly/models/file_item_model.dart';
import 'package:finderly/theme/folder_colors.dart';
import 'package:finderly/providers/background_provider.dart';

void main() {
  group('FolderColor', () {
    test('all 18 colors have labels and match fromName', () {
      expect(FolderColor.values.length, 18);
      for (final color in FolderColor.values) {
        expect(FolderColor.fromName(color.name), color);
        expect(color.label.isNotEmpty, true);
      }
      expect(FolderColor.fromName('unknown'), FolderColor.blue);
    });
  });

  group('AppBackground', () {
    test('all 5 backgrounds have valid labels and contrast colors', () {
      expect(AppBackground.values.length, 5);
      for (final bg in AppBackground.values) {
        expect(bg.label.isNotEmpty, true);
        expect(bg.textColor, isNotNull);
        expect(bg.iconColor, isNotNull);
        expect(bg.decoration, isNotNull);
      }
      expect(AppBackground.darkDots.isDark, true);
      expect(AppBackground.lightDots.isDark, false);
      expect(AppBackground.gray.isDark, false);
      expect(AppBackground.white.isDark, false);
      expect(AppBackground.pureBlack.isDark, true);
    });
  });

  group('FolderModel', () {
    test('serialization roundtrip', () {
      final now = DateTime.now();
      final folder = FolderModel(
        id: 'f1',
        name: 'Work',
        parentId: null,
        color: FolderColor.purple,
        createdAt: now,
        updatedAt: now,
        isDownloaded: true,
      );

      final map = folder.toMap();
      final revived = FolderModel.fromMap(map);

      expect(revived.id, 'f1');
      expect(revived.name, 'Work');
      expect(revived.parentId, null);
      expect(revived.color, FolderColor.purple);
      expect(revived.isDownloaded, true);
    });
  });

  group('FileItemModel', () {
    test('file extension and formatted size', () {
      final file = FileItemModel(
        id: 'file1',
        name: 'report.final.pdf',
        folderId: 'f1',
        localPath: '/tmp/report.final.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 2500000, // ~2.38 MB
        createdAt: DateTime.now(),
        isDownloaded: true,
      );

      expect(file.fileExtension, 'pdf');
      expect(file.formattedSize, '2.4 MB');
    });
  });
}

