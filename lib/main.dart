import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'views/home_page.dart';
import 'views/add_product_page.dart';
import 'views/edit_product_page.dart';
import 'views/rent_page.dart';
import 'views/return_page.dart';
import 'views/view_stock_page.dart';
import 'views/settings_page.dart';
import 'views/history_pages/added_history_page.dart';
import 'views/history_pages/rented_history_page.dart';
import 'views/history_pages/returned_history_page.dart';
import 'controllers/product_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/language_controller.dart';
import 'services/database_services.dart';

import 'translations/app_translations.dart';
import 'utils/toast_util.dart';
import 'utils/windows_security_util.dart';
import 'utils/desktop_scroll_behavior.dart';

// Create a MaterialColor from the hex color #f78e81 (Light Coral/Salmon)
MaterialColor createMaterialColor(Color color) {
  List<double> strengths = <double>[.05, .1, .2, .3, .4, .5, .6, .7, .8, .9];
  Map<int, Color> swatch = <int, Color>{};
  final int r = color.red, g = color.green, b = color.blue;

  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

// Define the primary color from hex #f78e81
final MaterialColor primaryColor = createMaterialColor(Color(0xFFf78e81));


void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    print('Initializing FFI for desktop platform');
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory
    databaseFactory = databaseFactoryFfi;
  }

  // Pre-initialize database service
  try {
    print('Pre-initializing database service...');
    // Access the instance to trigger initialization
    final dbService = DatabaseService.instance;
    // Try to access the database to ensure it's properly initialized
    await dbService.database;
    print('Database service initialized successfully');
  } catch (e) {
    print('Error pre-initializing database service: $e');
    // Continue anyway, the app will try to initialize the database again when needed
  }

  runApp(InventoryApp());
}

class InventoryApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Inventory Management',
      navigatorKey: ToastUtil.navigatorKey, // Important for toast notifications
      scrollBehavior: DesktopScrollBehavior(), // Enable mouse wheel scrolling
      theme: ThemeData(
        primarySwatch: primaryColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: CardTheme(elevation: 4, margin: EdgeInsets.all(8)),
        buttonTheme: ButtonThemeData(buttonColor: primaryColor, textTheme: ButtonTextTheme.primary),
      ),
      initialBinding: BindingsBuilder(() {
        Get.put(ProductController());
        Get.put(SettingsController());
        Get.put(LanguageController());
      }),
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      getPages: [
        GetPage(name: '/', page: () => MainPage()),
        GetPage(name: '/home', page: () => HomePage()),
        GetPage(name: '/add', page: () => AddProductPage()),
        GetPage(name: '/rent', page: () => RentPage()),
        GetPage(name: '/return', page: () => ReturnPage()),
        GetPage(name: '/stock', page: () => ViewStockPage()),
        GetPage(name: '/rental-history', page: () => RentalHistoryPage()),
        GetPage(name: '/return-history', page: () => ReturnHistoryPage()),
        GetPage(name: '/added-history', page: () => AddedProductHistoryPage()),
        GetPage(name: '/settings', page: () => SettingsPage()),
        GetPage(
          name: '/edit-product',
          page: () => EditProductPage(product: Get.arguments),
        ),
      ],
      initialRoute: '/',
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    HomePage(),
    AddProductPage(),
    RentPage(),
    ReturnPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Auto-initialize network service after a short delay to allow UI to load
    Future.delayed(Duration(milliseconds: 500), () {
      _initializeNetworkService();
    });
  }

  Future<void> _initializeNetworkService() async {
    try {
      // Show security messages on Windows
      if (Platform.isWindows) {
        // Show security messages with a delay between them
        WindowsSecurityUtil.showSecurityMessage();
        await Future.delayed(Duration(seconds: 2));
        WindowsSecurityUtil.showFirewallMessage();
        await Future.delayed(Duration(seconds: 2));
        WindowsSecurityUtil.showAntivirusMessage();
      }

      final settingsController = Get.find<SettingsController>();
      await settingsController.autoInitialize();
      print('Network service auto-initialized successfully');
    } catch (e) {
      print('Error auto-initializing network service: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'nav_home'.tr),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'nav_add'.tr),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'nav_rent'.tr),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_return), label: 'nav_return'.tr),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'settings_title'.tr),
        ],
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}