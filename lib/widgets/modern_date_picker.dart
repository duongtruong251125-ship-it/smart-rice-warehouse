import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class ModernDatePicker {
  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
    DateTime? minDate,
    DateTime? maxDate,
    String title = 'Chọn ngày',
  }) async {
    DateTime? selectedDate = initialDate;

    return await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            height: 420,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 12),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: SfDateRangePicker(
                    initialSelectedDate: initialDate,
                    minDate: minDate ?? DateTime(2000),
                    maxDate: maxDate ?? DateTime(2100),
                    selectionMode: DateRangePickerSelectionMode.single,
                    selectionColor: AppTheme.primaryColor,
                    todayHighlightColor: AppTheme.primaryColor,
                    headerStyle: const DateRangePickerHeaderStyle(
                      textStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    monthCellStyle: const DateRangePickerMonthCellStyle(
                      textStyle: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      todayTextStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                      selectedDate = args.value as DateTime;
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, selectedDate),
                      child: const Text('Xác nhận', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
