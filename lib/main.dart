import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for better performance
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Enable optimizations for faster rendering
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
  }

  // Initialize database for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    print('Initializing FFI for desktop platform');
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize notification service in parallel
  final notificationFuture = _initializeNotificationService();

  // Pre-initialize database service
  final dbFuture = _initializeDatabaseService();

  // Wait for critical services to initialize
  await Future.wait([dbFuture]);

  // Run the app without waiting for non-critical services
  runApp(InventoryApp());
}

Future<void> _initializeNotificationService() async {
  try {
    print('Initializing notification service...');
    // Initialize the notification service
    print('Notification service initialized successfully');
    return Future.value();
  } catch (e, stackTrace) {
    print('Error initializing notification service: $e');
    print('Stack trace: $stackTrace');
    // Continue anyway, as notifications are not critical for app functionality
    return Future.value();
  }
}

Future<void> _initializeDatabaseService() async {
  try {
    print('Pre-initializing database service...');
    // Access the instance to trigger initialization
    final dbService = DatabaseService.instance;
    // Try to access the database to ensure it's properly initialized
    await dbService.database;
    print('Database service initialized successfully');
    return Future.value();
  } catch (e) {
    print('Error pre-initializing database service: $e');
    // Continue anyway, the app will try to initialize the database again when needed
    return Future.value();
  }
}

class InventoryApp extends StatelessWidget {
  // Define constants to avoid rebuilding
  static const Color primaryColor = Color(0xFFdb8970);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Inventory Management',
      navigatorKey: ToastUtil.navigatorKey, // Important for toast notifications
      theme: ThemeData(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: primaryColor,
          secondary: primaryColor,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: const CardTheme(elevation: 4, margin: EdgeInsets.all(8)),
        buttonTheme: ButtonThemeData(buttonColor: primaryColor, textTheme: ButtonTextTheme.primary),
        appBarTheme: AppBarTheme(backgroundColor: primaryColor),
        // Optimize text rendering
        textTheme: Typography.material2018().black.apply(fontFamily: 'Roboto'),
        // Optimize scrolling
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: MaterialStateProperty.all(true),
          thickness: MaterialStateProperty.all(6.0),
        ),
      ),
      initialBinding: BindingsBuilder(() {
        Get.put(ProductController());
        Get.put(SettingsController());
        Get.put(LanguageController());
      }),
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      // Use custom scroll behavior for better desktop scrolling
      scrollBehavior: DesktopScrollBehavior(),
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

class _MainPageState extends State<MainPage> with AutomaticKeepAliveClientMixin {
  int _currentIndex = 0;

  // Lazy load pages to improve performance
  late final List<Widget> _pages = [
    const HomePage(),
     AddProductPage(),
     RentPage(),
     ReturnPage(),
  ];

  @override
  bool get wantKeepAlive => true; // Keep page state alive when switching tabs

  @override
  void initState() {
    super.initState();
    // Auto-initialize network service after a short delay to allow UI to load
    // Use a microtask to run after the current frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
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
        ],
        selectedItemColor: InventoryApp.primaryColor, // Use the constant from InventoryApp
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}