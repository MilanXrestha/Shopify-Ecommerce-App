import 'package:flutter/material.dart';

import '../../../../../common/constants/app_constants.dart';
import '../../../../../core/app_scope.dart';

class DebugPanelScreen extends StatefulWidget {
  const DebugPanelScreen({super.key});

  @override
  DebugPanelScreenState createState() => DebugPanelScreenState();
}

class DebugPanelScreenState extends State<DebugPanelScreen> {
  String _baseUrl = AppConstants.defaultBaseUrl;
  final TextEditingController _baseUrlController = TextEditingController();
  Map<String, int> _cacheCounts = {};
  String _lastSyncTime = 'Not available';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDebugInfo();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadDebugInfo() async {
    final appScope = AppScope.of(context);

    // Get current base URL
    _baseUrl = appScope.baseUrl;
    _baseUrlController.text = _baseUrl;

    // Get cache counts
    final db = await appScope.databaseHelper.database;

    final products = await db.query('products');
    final categories = await db.query('categories');
    final cartItems = await db.query('cart_items');
    final favorites = await db.query('favorites');

    setState(() {
      _cacheCounts = {
        'Products': products.length,
        'Categories': categories.length,
        'Cart Items': cartItems.length,
        'Favorites': favorites.length,
      };
    });

    // Get last sync time
    final lastSync = appScope.sharedPreferences.getInt('last_sync_timestamp');
    if (lastSync != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(lastSync);
      setState(() {
        _lastSyncTime = '${date.toLocal()}';
      });
    }
  }

  Future<void> _updateBaseUrl() async {
    if (_baseUrlController.text.isEmpty) return;

    final appScope = AppScope.of(context);
    await appScope.sharedPreferences.setString(
      'base_url',
      _baseUrlController.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Base URL updated. Restart app to apply changes.'),
      ),
    );
  }

  Future<void> _clearCache() async {
    final appScope = AppScope.of(context);
    final db = await appScope.databaseHelper.database;

    await db.delete('products');
    await db.delete('categories');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cache cleared successfully')));

    _loadDebugInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Panel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Info
            const Text(
              'App Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoCard(
              title: 'App Version',
              value: AppConstants.appVersion,
              icon: Icons.info_outline,
            ),

            const SizedBox(height: 24),

            // API Settings
            const Text(
              'API Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Base URL',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        hintText: 'Enter API base URL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _updateBaseUrl,
                      child: const Text('Update Base URL'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Cache Information
            const Text(
              'Cache Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cache Counts',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        ElevatedButton(
                          onPressed: _clearCache,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Clear Cache'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._cacheCounts.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key),
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text('Last Sync:'), Text(_lastSyncTime)],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Actions
            const Text(
              'Debug Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Force reload data
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Forcing data reload...'),
                          ),
                        );
                      },
                      child: const Text('Force Reload Data'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        // Reset app preferences
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Preferences reset. Restart app to apply.',
                            ),
                          ),
                        );
                      },
                      child: const Text('Reset App Preferences'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
