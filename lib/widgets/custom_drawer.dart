import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Text('Inventory Menu', style: TextStyle(fontSize: 24, color: Colors.white)),
            decoration: BoxDecoration(color: Colors.teal),
          ),
          ListTile(
            leading: Icon(Icons.inventory),
            title: Text('View Stock'),
            onTap: () => Get.toNamed('/stock'),
          ),
          ListTile(
            leading: Icon(Icons.shopping_cart),
            title: Text('Rental History'),
            onTap: () => Get.toNamed('/rental-history'),
          ),
          ListTile(
            leading: Icon(Icons.assignment_return),
            title: Text('Return History'),
            onTap: () => Get.toNamed('/return-history'),
          ),
          ListTile(
            leading: Icon(Icons.add_box),
            title: Text('Added Product History'),
            onTap: () => Get.toNamed('/added-history'),
          ),
        ],
      ),
    );
  }
}