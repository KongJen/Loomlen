import 'package:flutter/material.dart';
import 'package:frontend/pages/favorites_page.dart';
import 'package:frontend/pages/my_room_page.dart';
import 'package:frontend/pages/share_page.dart';

class NavigationMenu extends StatefulWidget {
  const NavigationMenu({super.key});

  @override
  State<NavigationMenu> createState() => BottomNavigationMenuState(); // Remove underscore
}

// Rename to public class
class BottomNavigationMenuState extends State<NavigationMenu> {
  int _selectedIndex = 0;
  bool _showBottomNav = true;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  static final List<Widget> _pages = <Widget>[
    MyRoomPage(),
    SharePage(),
    FavoritesPage(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Widget _buildNavigator(GlobalKey<NavigatorState> key, Widget page) {
    return Navigator(
      key: key,
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(builder: (context) => page);
      },
    );
  }

  void toggleBottomNavVisibility(bool show) {
    setState(() {
      _showBottomNav = show;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(
          _pages.length,
          (index) => _buildNavigator(_navigatorKeys[index], _pages[index]),
        ),
      ),
      bottomNavigationBar:
          _showBottomNav
              ? Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey, width: 1)),
                ),
                child: BottomNavigationBar(
                  items: <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person),
                            SizedBox(width: 10),
                            Text(
                              'My Room',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    _selectedIndex == 0
                                        ? Colors.blue[800]
                                        : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.share_rounded),
                            SizedBox(width: 10),
                            Text(
                              'Share',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    _selectedIndex == 1
                                        ? Colors.blue[800]
                                        : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.book_rounded),
                            SizedBox(width: 10),
                            Text(
                              'Favorites',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    _selectedIndex == 2
                                        ? Colors.blue[800]
                                        : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      label: '',
                    ),
                  ],
                  currentIndex: _selectedIndex,
                  selectedItemColor: Colors.blue[800],
                  unselectedItemColor: Colors.grey,
                  backgroundColor: Colors.white,
                  onTap: _onItemTapped,
                  iconSize: 40,
                  showSelectedLabels: false,
                  showUnselectedLabels: false,
                  type: BottomNavigationBarType.fixed,
                ),
              )
              : null,
    );
  }
}
