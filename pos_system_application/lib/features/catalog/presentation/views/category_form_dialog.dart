import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/category.dart';
import '../controllers/catalog_providers.dart';

class CategoryFormDialog extends ConsumerStatefulWidget {
  final CategoryModel? category;

  const CategoryFormDialog({super.key, this.category});

  @override
  ConsumerState<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  String? _parentId;
  late bool _isActive;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _codeController = TextEditingController(text: widget.category?.code ?? '');
    _parentId = widget.category?.parentId;
    _isActive = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final notifier = ref.read(categoryListProvider.notifier);

    try {
      if (widget.category == null) {
        await notifier.createCategory(
          name: _nameController.text.trim(),
          code: _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
          parentId: _parentId,
          isActive: _isActive,
        );
      } else {
        await notifier.updateCategory(
          id: widget.category!.id,
          name: _nameController.text.trim(),
          code: _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
          parentId: _parentId,
          isActive: _isActive,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final isEditing = widget.category != null;

    final potentialParents = categoriesAsync.maybeWhen(
      data: (cats) => cats.where((c) => c.id != widget.category?.id).toList(),
      orElse: () => <CategoryModel>[],
    );

    return AlertDialog(
      title: Text(isEditing ? 'Edit Category' : 'Create Category'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    ),
                  ),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name *',
                    hintText: 'e.g. Beverages',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Category name is required';
                    }
                    if (value.trim().length > 100) {
                      return 'Must be 100 characters or fewer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Category Code',
                    hintText: 'e.g. BEV',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: _parentId,
                  decoration: const InputDecoration(
                    labelText: 'Parent Category (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None (Top Level)'),
                    ),
                    ...potentialParents.map((cat) => DropdownMenuItem<String?>(
                          value: cat.id,
                          child: Text(cat.name),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _parentId = val;
                    });
                  },
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: const Text('Active Category'),
                  subtitle: const Text('Inactive categories are hidden in registers'),
                  value: _isActive,
                  onChanged: (val) {
                    setState(() {
                      _isActive = val;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save Changes' : 'Create'),
        ),
      ],
    );
  }
}
