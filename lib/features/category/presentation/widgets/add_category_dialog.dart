import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../../common/theme/app_colors.dart';

class AddCategoryDialog extends StatefulWidget {
  final Function(String name, String slug, String? imagePath) onAdd;

  const AddCategoryDialog({super.key, required this.onAdd});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _slug = '';
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updateSlug);
  }

  @override
  void dispose() {
    _nameController.removeListener(_updateSlug);
    _nameController.dispose();
    super.dispose();
  }

  void _updateSlug() {
    // Convert the name to a slug: lowercase, replace spaces with hyphens, remove special chars
    setState(() {
      _slug = _nameController.text
          .toLowerCase()
          .trim()
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-');
    });
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        // Store the image in the app's documents directory with a unique name
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            'category_${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedFile.path)}';
        final savedImage = await File(
          pickedFile.path,
        ).copy('${appDir.path}/$fileName');

        setState(() {
          _imageFile = savedImage;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom Category'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image selection
              GestureDetector(
                onTap: _isLoading ? null : _pickImage,
                child: Container(
                  height: 120.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12.r),
                    image: _imageFile != null
                        ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 40.w,
                              color: Colors.grey[500],
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'Add Category Image',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'Enter a name for your category',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12.h),
              // Show the generated slug
              if (_slug.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    children: [
                      const Text(
                        'Slug: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          _slug,
                          style: const TextStyle(fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
          ),
          onPressed: _isLoading
              ? null
              : () {
                  if (_formKey.currentState?.validate() ?? false) {
                    setState(() {
                      _isLoading = true;
                    });

                    // Pass the image path if image was selected
                    final imagePath = _imageFile?.path;
                    widget.onAdd(_nameController.text.trim(), _slug, imagePath);
                    Navigator.pop(context);
                  }
                },
          child: _isLoading
              ? SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
