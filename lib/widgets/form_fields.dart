import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ============================================================
// COMPONENTE: Campo de Texto
// ============================================================
class DynamicTextField extends StatelessWidget {
  final String label;
  final String? placeholder;
  final String? initialValue;
  final bool required;
  final TextInputType keyboardType;
  final int? maxLength;
  final int? minLength;
  final Function(String) onChanged;

  const DynamicTextField({
    super.key,
    required this.label,
    this.placeholder,
    this.initialValue,
    this.required = false,
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.minLength,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            if (required) const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: placeholder,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            counterText: maxLength != null ? null : '',
          ),
          onChanged: onChanged,
          validator: (value) {
            if (required && (value == null || value.isEmpty)) {
              return 'Este campo es obligatorio';
            }
            if (minLength != null && value != null && value.length < minLength!) {
              return 'Mínimo $minLength caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ============================================================
// COMPONENTE: Campo Número
// ============================================================
class DynamicNumberField extends StatelessWidget {
  final String label;
  final String? placeholder;
  final double? initialValue;
  final bool required;
  final double? min;
  final double? max;

  const DynamicNumberField({
    super.key,
    required this.label,
    this.placeholder,
    this.initialValue,
    this.required = false,
    this.min,
    this.max,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(
      text: initialValue?.toString() ?? '',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            if (required) const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: placeholder,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (value) {
            // El valor se maneja con controller
          },
          validator: (value) {
            if (required && (value == null || value.isEmpty)) {
              return 'Este campo es obligatorio';
            }
            if (value != null && value.isNotEmpty) {
              final numValue = double.tryParse(value);
              if (numValue == null) return 'Ingrese un número válido';
              if (min != null && numValue < min!) return 'Valor mínimo: $min';
              if (max != null && numValue > max!) return 'Valor máximo: $max';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ============================================================
// COMPONENTE: Selector Único (Dropdown)
// ============================================================
class DynamicDropdown extends StatefulWidget {
  final String label;
  final List<String> options;
  final String? initialValue;
  final bool required;
  final Function(String) onChanged;

  const DynamicDropdown({
    super.key,
    required this.label,
    required this.options,
    this.initialValue,
    this.required = false,
    required this.onChanged,
  });

  @override
  State<DynamicDropdown> createState() => _DynamicDropdownState();
}

class _DynamicDropdownState extends State<DynamicDropdown> {
  late String? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            if (widget.required) const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedValue,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: widget.options.map((option) {
            return DropdownMenuItem(value: option, child: Text(option));
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedValue = value);
            widget.onChanged(value ?? '');
          },
          validator: (value) {
            if (widget.required && (value == null || value.isEmpty)) {
              return 'Seleccione una opción';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ============================================================
// COMPONENTE: Selección Múltiple (Checkboxes)
// ============================================================
class DynamicCheckboxGroup extends StatefulWidget {
  final String label;
  final List<String> options;
  final List<String>? initialValues;
  final bool required;
  final Function(List<String>) onChanged;

  const DynamicCheckboxGroup({
    super.key,
    required this.label,
    required this.options,
    this.initialValues,
    this.required = false,
    required this.onChanged,
  });

  @override
  State<DynamicCheckboxGroup> createState() => _DynamicCheckboxGroupState();
}

class _DynamicCheckboxGroupState extends State<DynamicCheckboxGroup> {
  late Map<String, bool> _selectedValues;

  @override
  void initState() {
    super.initState();
    _selectedValues = {};
    for (var option in widget.options) {
      _selectedValues[option] = widget.initialValues?.contains(option) ?? false;
    }
  }

  void _notifyChange() {
    final selected = _selectedValues.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            if (widget.required) const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: widget.options.map((option) {
              return CheckboxListTile(
                title: Text(option),
                value: _selectedValues[option],
                onChanged: (value) {
                  setState(() => _selectedValues[option] = value ?? false);
                  _notifyChange();
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ============================================================
// COMPONENTE: Selector de Fecha
// ============================================================
class DynamicDatePicker extends StatefulWidget {
  final String label;
  final DateTime? initialValue;
  final bool required;
  final bool includeTime;
  final Function(DateTime) onChanged;

  const DynamicDatePicker({
    super.key,
    required this.label,
    this.initialValue,
    this.required = false,
    this.includeTime = false,
    required this.onChanged,
  });

  @override
  State<DynamicDatePicker> createState() => _DynamicDatePickerState();
}

class _DynamicDatePickerState extends State<DynamicDatePicker> {
  late DateTime? _selectedDate;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialValue;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'MX'),
    );

    if (picked != null) {
      if (widget.includeTime) {
        _selectTime(context, picked);
      } else {
        setState(() => _selectedDate = picked);
        widget.onChanged(picked);
      }
    }
  }

  Future<void> _selectTime(BuildContext context, DateTime date) async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate ?? DateTime.now()),
    );

    if (time != null) {
      final finalDate = DateTime(
        date.year, date.month, date.day,
        time.hour, time.minute,
      );
      setState(() => _selectedDate = finalDate);
      widget.onChanged(finalDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            if (widget.required) const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDate != null
                      ? (widget.includeTime
                          ? _dateTimeFormat.format(_selectedDate!)
                          : _dateFormat.format(_selectedDate!))
                      : 'Seleccionar fecha',
                  style: TextStyle(
                    color: _selectedDate != null ? Colors.black : Colors.grey,
                  ),
                ),
                Icon(Icons.calendar_today, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ============================================================
// COMPONENTE: Switch (Sí/No)
// ============================================================
class DynamicSwitch extends StatefulWidget {
  final String label;
  final bool? initialValue;
  final bool required;
  final Function(bool) onChanged;

  const DynamicSwitch({
    super.key,
    required this.label,
    this.initialValue,
    this.required = false,
    required this.onChanged,
  });

  @override
  State<DynamicSwitch> createState() => _DynamicSwitchState();
}

class _DynamicSwitchState extends State<DynamicSwitch> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            if (widget.required) const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_value ? 'Sí' : 'No'),
              Switch(
                value: _value,
                onChanged: (value) {
                  setState(() => _value = value);
                  widget.onChanged(value);
                },
                activeColor: const Color(0xFF3498db),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}