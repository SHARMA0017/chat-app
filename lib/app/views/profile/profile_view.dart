import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('profile'.tr),
        actions: [
          Obx(() => IconButton(
            onPressed: controller.isEditing.value 
                ? controller.saveProfile 
                : controller.toggleEdit,
            icon: Icon(
              controller.isEditing.value ? Icons.save : Icons.edit,
            ),
          )),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Text(
                      (controller.currentUser?.displayName ?? 'U')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    controller.currentUser?.displayName ?? 'Unknown User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.currentUser?.email ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Profile Form
            Obx(() => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Display Name
                    TextFormField(
                      controller: controller.displayNameController,
                      enabled: controller.isEditing.value,
                      decoration: InputDecoration(
                        labelText: 'display_name'.tr,
                        prefixIcon: const Icon(Icons.person),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Email (read-only)
                    TextFormField(
                      initialValue: controller.currentUser?.email,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'email'.tr,
                        prefixIcon: const Icon(Icons.email),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Mobile
                    TextFormField(
                      controller: controller.mobileController,
                      enabled: controller.isEditing.value,
                      decoration: InputDecoration(
                        labelText: 'mobile'.tr,
                        prefixIcon: const Icon(Icons.phone),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Country (read-only)
                    TextFormField(
                      initialValue: controller.currentUser?.country,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'country'.tr,
                        prefixIcon: const Icon(Icons.flag),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    
                    if (controller.isEditing.value) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: controller.toggleEdit,
                              child: Text('cancel'.tr),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Obx(() => ElevatedButton(
                              onPressed: controller.isLoading.value 
                                  ? null 
                                  : controller.saveProfile,
                              child: controller.isLoading.value
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text('save'.tr),
                            )),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            )),
            
            const SizedBox(height: 16),
            
            // Settings Section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text('change_language'.tr),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: controller.changeLanguage,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.qr_code),
                    title: Text('generate_qr'.tr),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: controller.goToQRGenerator,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('Device Information'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: controller.showDeviceInfo,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: Text(
                      'logout'.tr,
                      style: const TextStyle(color: Colors.red),
                    ),
                    onTap: controller.logout,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // App Info
            Text(
              'Chat App v1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
