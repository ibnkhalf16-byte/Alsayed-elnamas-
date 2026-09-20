import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  /// دالة التحقق الأمني من كلمة المرور قبل العمليات الحساسة (حذف/تعديل)
  static Future<bool> verifyPassword(BuildContext context) async {
    final pwdCtrl = TextEditingController();
    final supabase = Supabase.instance.client;
    
    // جلب الباسورد من السحابة
    final row = await supabase.from('settings').select().eq('key', 'password_hash');
    final storedHash = row.isNotEmpty 
        ? row.first['value'] as String 
        : sha256.convert(utf8.encode('1234')).toString();

    final isAuthorized = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.security, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'حماية العمليات',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'يرجى إدخال كلمة المرور لتأكيد تنفيذ العملية:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pwdCtrl,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.visiblePassword,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final enteredHash = sha256.convert(utf8.encode(pwdCtrl.text.trim())).toString();
                if (enteredHash == storedHash) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('كلمة المرور غير صحيحة!'),
                      backgroundColor: AppColors.payableRed,
                    ),
                  );
                }
              },
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );

    return isAuthorized ?? false;
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPwdCtrl.text.trim() != _confirmPwdCtrl.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور الجديدة غير متطابقة مع التأكيد!'),
          backgroundColor: AppColors.payableRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final row = await supabase.from('settings').select().eq('key', 'password_hash');
      final storedHash = row.isNotEmpty 
          ? row.first['value'] as String 
          : sha256.convert(utf8.encode('1234')).toString();

      final enteredOldHash = sha256.convert(utf8.encode(_oldPwdCtrl.text.trim())).toString();

      if (enteredOldHash != storedHash) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('كلمة المرور الحالية غير صحيحة!'),
              backgroundColor: AppColors.payableRed,
            ),
          );
        }
        return;
      }

      final newHash = sha256.convert(utf8.encode(_newPwdCtrl.text.trim())).toString();
      
      // حفظ في قاعدة البيانات السحابية Supabase
      await supabase.from('settings').upsert({
        'key': 'password_hash',
        'value': newHash
      });

      _oldPwdCtrl.clear();
      _newPwdCtrl.clear();
      _confirmPwdCtrl.clear();

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث كلمة المرور بنجاح ✅'),
            backgroundColor: AppColors.receivableGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحديث كلمة المرور: $e'),
            backgroundColor: AppColors.payableRed,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات النظام والأمان'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_reset, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'تغيير كلمة المرور الرئيسية',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'تستخدم كلمة المرور لتأكيد عمليات التعديل والحذف لكافة السجلات.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const Divider(height: 24),
                        TextFormField(
                          controller: _oldPwdCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'كلمة المرور الحالية',
                            prefixIcon: Icon(Icons.key_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newPwdCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'كلمة المرور الجديدة',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'مطلوب';
                            if (v.trim().length < 4) return 'يجب ألا تقل عن 4 رموز';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPwdCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'تأكيد كلمة المرور الجديدة',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updatePassword,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('حفظ كلمة المرور الجديدة'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFFEFF6FF),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.infoBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'تنبيه: كلمة المرور الافتراضية للنظام هي: 1234',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cloud_done, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'بيانات التطبيق وقاعدة البيانات',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'قاعدة البيانات الحالية: تم الربط بنجاح مع السحابة (Supabase).\nيتم الآن حفظ وجلب جميع البيانات بشكل آمن ولا مركزية عبر الإنترنت.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
