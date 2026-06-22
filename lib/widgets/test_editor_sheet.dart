// widgets/test_editor_sheet.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import '../models/course_model.dart';

/// Bottom sheet to create or edit a [CourseTest]. Returns the test on save.
class TestEditorSheet extends StatefulWidget {
  const TestEditorSheet({super.key, this.initial});

  final CourseTest? initial;

  static Future<CourseTest?> show(BuildContext context, {CourseTest? initial}) {
    return showModalBottomSheet<CourseTest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TestEditorSheet(initial: initial),
    );
  }

  @override
  State<TestEditorSheet> createState() => _TestEditorSheetState();
}

class _TestEditorSheetState extends State<TestEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _portionCtrl;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? 'Unit Test 1');
    _portionCtrl = TextEditingController(text: widget.initial?.portion ?? '');
    _date = widget.initial?.date ?? DateTime.now().add(const Duration(days: 14));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _portionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.initial == null ? 'Add test' : 'Edit test',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                )),
            const Gap(AppSpacing.md),
            AppTextField(controller: _nameCtrl, labelText: 'Name'),
            const Gap(AppSpacing.sm),
            AppTextField(
              controller: _portionCtrl,
              labelText: 'Portion',
              hintText: 'e.g. Unit 1 and Unit 2',
              maxLines: 2,
            ),
            const Gap(AppSpacing.sm),
            AppCard(
              onTap: _pickDate,
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 18, color: colors.textSecondary),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: Text(DateFormat('EEEE, d MMM yyyy').format(_date),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colors.textPrimary)),
                  ),
                  Icon(Icons.edit_outlined, size: 16, color: colors.textTertiary),
                ],
              ),
            ),
            const Gap(AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (_nameCtrl.text.trim().isEmpty) return;
                      Navigator.pop(
                        context,
                        CourseTest(
                          id: widget.initial?.id ?? const Uuid().v4(),
                          name: _nameCtrl.text.trim(),
                          date: _date,
                          portion: _portionCtrl.text.trim(),
                        ),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
