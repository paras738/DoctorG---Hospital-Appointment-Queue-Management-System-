import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/family_member_model.dart';
import '../../data/repositories/supabase_booking_repository.dart';
import '../controllers/booking_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class AddFamilyMemberSheet extends ConsumerStatefulWidget {
  const AddFamilyMemberSheet({super.key});

  @override
  ConsumerState<AddFamilyMemberSheet> createState() =>
      _AddFamilyMemberSheetState();
}

class _AddFamilyMemberSheetState extends ConsumerState<AddFamilyMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _relationship = 'Spouse';
  String _gender = 'Male';
  bool _isLoading = false;

  final _relationships = ['Spouse', 'Child', 'Parent', 'Sibling', 'Other'];
  final _genders = ['Male', 'Female', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(bookingRepositoryProvider);
      final member = FamilyMemberModel(
        id: '',
        userId: user.id,
        name: _nameController.text.trim(),
        relationship: _relationship,
        age: int.parse(_ageController.text.trim()),
        gender: _gender,
      );

      final added = await repo.addFamilyMember(member);
      ref.read(selectedFamilyMemberProvider.notifier).state = added;
      ref.refresh(familyMembersListProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add family member: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Family Member',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'e.g. Priya Verma',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name required' : null,
            ),
            const SizedBox(height: 12),

            // Relationship Dropdown
            DropdownButtonFormField<String>(
              value: _relationship,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                prefixIcon: Icon(Icons.family_restroom),
              ),
              items: _relationships
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _relationship = val);
              },
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                // Age
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age (Years)',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Age required';
                      final n = int.tryParse(v);
                      if (n == null || n < 0 || n > 120) return 'Invalid age';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Gender
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: _genders
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _gender = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: _isLoading ? null : _handleSave,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save & Select'),
            ),
          ],
        ),
      ),
    );
  }
}
