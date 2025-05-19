import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Enhanced Drawer Header with Logo
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Color(0xFFdb8970), // Salmon/coral color
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(8),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/Logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // App Name
                Text(
                  'Inventory Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                // Tagline
                Text(
                  'Manage your inventory efficiently',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  icon: Icons.home,
                  title: 'Home',
                  onTap: () => Get.offAllNamed('/'),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.inventory,
                  title: 'view_stock'.tr,
                  onTap: () => Get.toNamed('/stock'),
                ),
                _buildMenuItem(
                  icon: Icons.shopping_cart,
                  title: 'rental_history'.tr,
                  onTap: () => Get.toNamed('/rental-history'),
                ),
                _buildMenuItem(
                  icon: Icons.assignment_return,
                  title: 'return_history'.tr,
                  onTap: () => Get.toNamed('/return-history'),
                ),
                _buildMenuItem(
                  icon: Icons.add_box,
                  title: 'added_history'.tr,
                  onTap: () => Get.toNamed('/added-history'),
                ),
              ],
            ),
          ),
          // Footer
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Color(0xFFdb8970).withOpacity(0.1),
              border: Border(top: BorderSide(color: Color(0xFFdb8970).withOpacity(0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFFdb8970)),
                SizedBox(width: 8),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(fontSize: 12, color: Color(0xFFdb8970), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
  // Helper method to build menu items
  Widget _buildMenuItem({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFFdb8970)),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
    );
  }

  // Helper method to build dividers
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 20,
      endIndent: 20,
      color: Color(0xFFdb8970).withOpacity(0.2),
    );
  }
}