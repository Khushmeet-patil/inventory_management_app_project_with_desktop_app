import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Text('inventory_menu'.tr, style: TextStyle(fontSize: 24, color: Colors.white)),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
          ),
          ListTile(
            leading: Icon(Icons.inventory),
            title: Text('view_stock'.tr),
            onTap: () => Get.toNamed('/stock'),
          ),
          ListTile(
            leading: Icon(Icons.shopping_cart),
            title: Text('rental_history'.tr),
            onTap: () => Get.toNamed('/rental-history'),
          ),
          ListTile(
            leading: Icon(Icons.assignment_return),
            title: Text('return_history'.tr),
            onTap: () => Get.toNamed('/return-history'),
          ),
          ListTile(
            leading: Icon(Icons.add_box),
            title: Text('added_history'.tr),
            onTap: () => Get.toNamed('/added-history'),
          ),
        ],
      ),
    );
  }
}