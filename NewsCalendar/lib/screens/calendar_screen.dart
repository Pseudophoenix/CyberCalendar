import '../utils/imports.dart';
import '../models/events.dart' as eventModel;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FullScreenCalendar extends StatefulWidget {
  @override
  _FullScreenCalendarState createState() => _FullScreenCalendarState();
}

class _FullScreenCalendarState extends State<FullScreenCalendar> {
  DateTime _focusedDay = DateTime.now();
  late final Box<eventModel.Event> _eventsBox;
  late final Box<eventModel.Event> _pendingOperationsBox;
  DateTime? _selectedDay;
  final Uuid _uuid = Uuid();
  OverlayEntry? _overlayEntry;
  AnimationController? _animationController;
  Map<String, List<eventModel.Event>> _events = {};
  List<String> _eventIds = []; // Changed to store event IDs instead of dates
  final String apiBaseUrl = '$SOCK_BASE_URL';
  WebSocketChannel? _channel;
  String? _currentUserId;
  String _newEventTitle = '';
  String _newEventDescription = '';
  FocusNode _focusNode = FocusNode();
  late AuthService _authService;
  bool _isWebSocketInitialized = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _setupConnectivityListener();
    _initializeHiveBoxes();
    _authService = Provider.of<AuthService>(context, listen: false);
    _connectToWebSocket();
    _focusNode.canRequestFocus = false;
  }

  void _setupConnectivityListener() {
    final connectivity = Provider.of<ConnectivityProvider>(
      context,
      listen: false,
    );
    connectivity.addListener(_handleConnectivityChange);
    if (connectivity.isOnline) {
      _initializeWebSocket();
    }
  }

  void _handleConnectivityChange() {
    final connectivity = Provider.of<ConnectivityProvider>(
      context,
      listen: false,
    );
    if (connectivity.isOnline && !_isWebSocketInitialized) {
      _initializeWebSocket();
      _processPendingEvents();
    } else if (!connectivity.isOnline) {
      _channel?.sink.close();
      _channel = null;
      _isWebSocketInitialized = false;
    }
  }

  void _processPendingEvents() async {
    if (!Provider.of<ConnectivityProvider>(context, listen: false).isOnline)
      return;

    final pendingEvents = _pendingOperationsBox.values.toList();

    for (final event in pendingEvents) {
      try {
        switch (event.changeType) {
          case "CREATE":
            await _syncEventToRemote(event);
            break;
          case "UPDATE":
            await _syncUpdateToRemote(event);
            break;
          case "DELETE":
            await _syncDeleteToRemote(event.id, event);
            break;
        }
      } catch (e) {
        debugPrint('Failed to sync pending event ${event.id}: $e');
      }
    }
  }

  Future<void> _syncEventToRemote(eventModel.Event event) async {
    try {
      // First update local copy to mark as syncing
      final syncingEvent = event.copyWith(isSynced: false);
      _eventsBox.put(syncingEvent.id, syncingEvent);
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;
      print("+++++++++++++++++");
      print(event.toJson());
      // Make the API call
      final response = await http.post(
        Uri.parse('$BASE_URL/'),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer ${token}",
        },
        body: jsonEncode(event.toJson()),
      );
      print(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // _channel?.sink.add('{"action":"refresh"}');
        // Update local copy to mark as synced
        _channel?.stream.listen((message) {
          _processWebSocketMessage(message);
        });
        print(response.body);
        final syncedEvent = event.copyWith(isSynced: true);
        _eventsBox.put(syncedEvent.id, syncedEvent);

        // Remove from pending queue if it exists there
        if (_pendingOperationsBox.containsKey(event.id)) {
          _pendingOperationsBox.delete(event.id);
        }
      } else {
        // If sync fails, add to pending queue
        final failedEvent = event.copyWith(
          isSynced: false,
          changeType: "CREATE",
        );
        _pendingOperationsBox.put(failedEvent.id, failedEvent);
        _showSyncStatusSnackbar("Sync failed. Will retry later.");
      }
    } catch (e) {
      // On error, add to pending queue
      final failedEvent = event.copyWith(isSynced: false, changeType: "CREATE");
      _pendingOperationsBox.put(failedEvent.id, failedEvent);
      _showSyncStatusSnackbar("Network error. Will retry when online.");
    }
  }

  // void _updateEvent(eventModel.Event event) {}

  Future<void> _syncUpdateToRemote(eventModel.Event event) async {
    try {
      // First update local copy to mark as syncing
      final syncingEvent = event.copyWith(isSynced: false);
      _eventsBox.put(syncingEvent.id, syncingEvent);
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;
      // Make the API call
      final response = await http.put(
        Uri.parse('$BASE_URL/${event.id}'),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer ${token}",
        },
        body: jsonEncode(event.toJson()),
      );
      print("${response.body}ppppppppppppp");

      if (response.statusCode == 200) {
        // Update local copy to mark as synced
        final syncedEvent = event.copyWith(isSynced: true);
        _eventsBox.put(syncedEvent.id, syncedEvent);

        // Remove from pending queue if it exists there
        if (_pendingOperationsBox.containsKey(event.id)) {
          _pendingOperationsBox.delete(event.id);
        }
      } else {
        // If sync fails, add to pending queue
        final failedEvent = event.copyWith(
          isSynced: false,
          changeType: "UPDATE",
        );
        _pendingOperationsBox.put(failedEvent.id, failedEvent);
        _showSyncStatusSnackbar("Update failed. Will retry later.");
      }
    } catch (e) {
      // On error, add to pending queue
      final failedEvent = event.copyWith(isSynced: false, changeType: "UPDATE");
      _pendingOperationsBox.put(failedEvent.id, failedEvent);
      _showSyncStatusSnackbar("Network error. Will retry when online.");
    }
  }

  void _showSyncStatusSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _syncDeleteToRemote(
    String eventId,
    eventModel.Event event,
  ) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;
      // Make the API call
      print(event.toJson());
      print("${eventId}lllllllllllllllll");
      print(event.userId);
      final response = await http.delete(
        Uri.parse('$BASE_URL/$eventId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userId': event.userId}),
      );
      print("${response.body}ppppppppppppp");

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Remove from pending queue if it exists there
        if (_pendingOperationsBox.containsKey(eventId)) {
          _pendingOperationsBox.delete(eventId);
        }
      } else {
        // If sync fails, add to pending queue
        final failedEvent = event.copyWith(
          isSynced: false,
          changeType: "DELETE",
        );
        _pendingOperationsBox.put(failedEvent.id, failedEvent);
        _showSyncStatusSnackbar("Deletion failed. Will retry later.");
      }
    } catch (e) {
      // On error, add to pending queue
      final failedEvent = event.copyWith(isSynced: false, changeType: "DELETE");
      _pendingOperationsBox.put(failedEvent.id, failedEvent);
      _showSyncStatusSnackbar("Network error. Will retry when online.");
    }
  }

  Future<void> _initializeHiveBoxes() async {
    _eventsBox = Hive.box<eventModel.Event>('events');
    _pendingOperationsBox = Hive.box<eventModel.Event>('pending-operations');
  }

  void _initializeWebSocket() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    try {
      _channel = IOWebSocketChannel.connect(
        '$SOCK_BASE_URL?token=$token',
        headers: {'Authorization': 'Bearer $token'},
      );

      _channel?.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['type'] == 'ack') {
            _pendingOperationsBox.delete(data['id']);
          }
        },
        onError: (err) {
          debugPrint('WebSocket error: $err');
          _channel?.sink.close();
          _channel = null;
          _isWebSocketInitialized = false;
        },
      );
      _isWebSocketInitialized = true;
    } catch (e) {
      debugPrint('WebSocket initialization error: $e');
      _isWebSocketInitialized = false;
    }
  }

  Future<void> _getCurrentUser() async {
    // final authService = Provider.of<AuthService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);

    try {
      dynamic userData = await userService.getUserData();
      if (userData != null && userData['_id'] != null) {
        setState(() {
          _currentUserId = userData['_id'];
        });
      }
    } catch (e) {
      // print('Error getting user data: $e');
    }
  }

  Future<void> _updateEventViaWebSocket(
    eventModel.Event updatedEvent,
    String eventId,
  ) async {
    print(updatedEvent.toJson());
    // Always update local database first
    final isOnline =
        Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    final eventToUpdate = updatedEvent.copyWith(isSynced: isOnline);
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    // Always update local database first
    _eventsBox.put(eventToUpdate.id, eventToUpdate);

    if (isOnline) {
      // If online, try to sync immediately
      try {
        final message = json.encode({
          "action": "createEvent",
          "event": updatedEvent,
          "token": token, // Include the token for authentication
        });
        print(token);
        // _channel!.sink.add(message);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Creating event...'),
            duration: Duration(milliseconds: 90),
          ),
        );
        // _channel!.sink.add(message);
      } catch (e) {
        print(e);
      }
      _syncUpdateToRemote(eventToUpdate);
    } else {
      // If offline, add to pending queue with isSynced = false
      try {
        final pendingEvent = eventToUpdate.copyWith(
          isSynced: false,
          changeType: "UPDATE",
        );

        if (_channel == null || token == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Not connected or not authenticated'),
              duration: Duration(milliseconds: 90),
            ),
          );
          return;
        }

        _pendingOperationsBox.put(pendingEvent.id, pendingEvent);
        _showSyncStatusSnackbar("Update saved locally. Will sync when online.");
        // final message = json.encode({
        //   "action": "updateEvent",
        //   "eventId": eventId,
        //   "updates":
        //       updatedEvent, // Changed from "event" to "updates" to match backend
        //   "token": token,
        // });

        // _channel!.sink.add(message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updating event...'),
            duration: Duration(milliseconds: 90),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update event: $e'),
            duration: Duration(milliseconds: 90),
          ),
        );
      }
    }
  }

  Future<void> _createEventViaWebSocket(Map<String, dynamic> eventData) async {
    print("---------------------------------");
    print(DateFormat("dd-MM-yyyy").parse(eventData['end_date']).runtimeType);
    print(eventData['start_date'].runtimeType);
    print(eventData['userId'].runtimeType);
    final isOnline =
        Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    print(
      "dddddddddddddddddddd${(DateFormat("dd-MM-yyyy").parse(eventData['start_date']))}",
    );
    final newEvent = eventModel.Event.create(
      id: _uuid.v4(),
      title: eventData['title'],
      description: eventData['description'],
      startDate: DateFormat("dd-MM-yyyy").parse(eventData['start_date']),
      userId: _currentUserId,
      changeType: "CREATE",
      endDate: DateFormat("dd-MM-yyyy").parse(eventData['end_date']),
    );
    print("-------------------------------${isOnline}");
    // _addEvent(newEvent);
    final eventToStore = newEvent.copyWith(isSynced: isOnline);
    _eventsBox.put(eventToStore.id, eventToStore);
    print("This is create))))))))");
    if (isOnline) {
      // If online, try to sync immediately
      try {
        final message = json.encode({
          "action": "createEvent",
          "event": eventData.toString(),
          "token": token, // Include the token for authentication
        });
        print(token);
        // _channel!.sink.add(message);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Creating event...'),
            duration: Duration(milliseconds: 90),
          ),
        );
        // _channel!.sink.add(message);
      } catch (e) {
        print(e);
      }
      _syncEventToRemote(eventToStore);
    } else {
      // If offline, add to pending queue with isSynced = false
      try {
        final pendingEvent = eventToStore.copyWith(
          isSynced: false,
          changeType: "CREATE",
        );
        print("${eventData}");
        _pendingOperationsBox.put(pendingEvent.id, pendingEvent);
        _showSyncStatusSnackbar("Event saved locally. Will sync when online.");
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create event: $e'),
            duration: Duration(milliseconds: 90),
          ),
        );
      }
    }
    if (_channel == null || token == null) {
      print("This )");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not connected or not authenticated'),
          duration: Duration(milliseconds: 90),
        ),
      );
      return;
    }
  }

  // Modify the _connectToWebSocket method to handle event creation responses
  void _connectToWebSocket() {
    try {
      _getCurrentUser();
      _channel?.sink.close();
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;
      _channel = IOWebSocketChannel.connect(
        '$apiBaseUrl?token=$token',
        headers: {'Authorization': 'Bearer $token'},
      );

      _channel?.stream.listen(
        (message) {
          print(message);
          _processWebSocketMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          Future.delayed(Duration(seconds: 5), _connectToWebSocket);
        },
        onDone: () {
          print('WebSocket connection closed');
          Future.delayed(Duration(seconds: 5), _connectToWebSocket);
        },
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      Future.delayed(Duration(seconds: 5), _connectToWebSocket);
    }
  }

  void _processWebSocketMessage(dynamic message) {
    try {
      final responseData = json.decode(message);
      print('WebSocket message: $responseData');

      if (responseData["type"] == "events") {
        print(">>>>>>>>>>");
        final newEvents = <String, List<eventModel.Event>>{};
        final newEventIds = <String>[];

        for (var eventData in responseData["data"]) {
          final eventId = eventData['id'].toString();
          print("%%%%%%%%");
          if (!_events.containsKey(eventId)) {
            newEvents[eventId] = [];
            newEventIds.add(eventId);
            print("Adding new event ID: $eventId");
          }

          newEvents[eventId]!.add(eventModel.Event.fromJson(eventData));
        }

        setState(() {
          _events.addAll(newEvents);
          _eventIds.addAll(newEventIds);
          _eventIds = _eventIds.toSet().toList();
        });
      } else if (responseData["type"] == "eventCreated") {
        // Handle successful event creation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event created successfully'),
            duration: Duration(seconds: 2),
          ),
        );
        // Refresh the entire state
        setState(() {
          _channel?.sink.add('{"action":"refresh"}');
        });
      } else if (responseData["type"] == "eventUpdated") {
        // Handle successful event update
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );

        // Refresh the state
        setState(() {
          if (responseData["event"] != null) {
            final updatedEvent = eventModel.Event.fromJson(
              responseData["event"],
            );
            _events[updatedEvent.id] = [updatedEvent];
          } else {
            _channel?.sink.add('{"action":"refresh"}');
          }
        });
      } else if (responseData["type"] == "eventDeleted") {
        // Handle successful event deletion
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event deleted successfully'),
            duration: Duration(seconds: 2),
          ),
        );

        // Refresh the state
        setState(() {
          if (responseData["eventId"] != null) {
            final eventId = responseData["eventId"].toString();
            _events.remove(eventId);
            _eventIds.remove(eventId);
          } else {
            _channel?.sink.add('{"action":"refresh"}');
          }
        });
      } else if (responseData["type"] == "error") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData["message"] ?? 'Error occurred'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing server message: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteEventViaWebSocket(
    String eventId,
    eventModel.Event event,
  ) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    print(token);
    print(_channel);
    final isOnline =
        Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    _eventsBox.delete(eventId);
    if (isOnline) {
      try {
        final message = json.encode({
          "action": "deleteEvent",
          "eventId": event.id,
          "event": event,
          "token": token, // Include the token for authentication
        });
        print(token);
        // _channel!.sink.add(message);
        print(message);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleting event...'),
            duration: Duration(milliseconds: 90),
          ),
        );
        // _channel!.sink.add(message);
        _syncDeleteToRemote(eventId, event);
      } catch (e) {
        print(e);
      }
    } else {
      // If offline, add to pending queue with isSynced = false
      try {
        final pendingEvent = event.copyWith(
          isSynced: false,
          changeType: "DELETE",
        );
        _pendingOperationsBox.put(pendingEvent.id, pendingEvent);
        _showSyncStatusSnackbar(
          "Deletion saved locally. Will sync when online.",
        );
        if (_channel == null || token == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Not connected or not authenticated'),
              duration: Duration(milliseconds: 90),
            ),
          );
          return;
        }

        // final message = json.encode({
        //   "action": "deleteEvent",
        //   "eventId": eventId,
        //   "token": token,
        // });

        // _channel!.sink.add(message);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleting event...'),
            duration: Duration(milliseconds: 90),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete event: $e'),
            duration: Duration(milliseconds: 90),
          ),
        );
      }
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _channel?.sink.close();
    _animationController?.dispose();
    _animationController = null;
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    final screenHeight = MediaQuery.of(context).size.height;
    final dayBoxHeight = (screenHeight - 150) / 7;
    final calendarColors = Theme.of(context).extension<CalendarColors>()!;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _channel?.sink.add('{"action":"refresh"}');
              setState(() {});
            },
          ),
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            color: isOnline ? Colors.green : Colors.red,
          ),
        ],
      ),
      body: TableCalendar(
        firstDay: DateTime.utc(2000, 1, 1),
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        sixWeekMonthsEnforced: true,
        lastDay: DateTime.utc(2050, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          if (selectedDay.month != _focusedDay.month) {
            return;
          }
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          _showDayOverlay(selectedDay, context);
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        calendarFormat: CalendarFormat.month,
        eventLoader: (day) {
          final dayEvents =
              _events.values.expand((eventList) => eventList).where((event) {
                try {
                  final eventDate = event.startDate;
                  return isSameDay(day, eventDate);
                } catch (e) {
                  return false;
                }
              }).toList();
          return dayEvents;
        },
        calendarStyle: CalendarStyle(
          markersMaxCount: 1,
          markerDecoration: BoxDecoration(
            color: calendarColors.otherUserFont,
            shape: BoxShape.circle,
          ),
          markersAlignment: Alignment.bottomCenter,
          markersOffset: PositionedOffset(bottom: 2),
          cellMargin: EdgeInsets.all(2),
          cellPadding: EdgeInsets.all(4),
          defaultTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          weekendTextStyle: TextStyle(
            color: isDarkMode ? Colors.red[200] : Colors.red,
          ),
          defaultDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          todayDecoration: BoxDecoration(
            color: calendarColors.todayEventBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          selectedDecoration: BoxDecoration(
            color: calendarColors.selectedEventBackground,
            shape: BoxShape.circle,
          ),
          weekendDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          outsideTextStyle: TextStyle(color: calendarColors.differentMonthFont),
          outsideDecoration: BoxDecoration(
            shape: BoxShape.circle,
            color: calendarColors.differentMonthBackground,
          ),
          cellAlignment: Alignment.center,
        ),
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: Colors.white,
            size: 32,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: Colors.white,
            size: 32,
          ),
          headerPadding: EdgeInsets.symmetric(vertical: 8),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          weekendStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.red[200] : Colors.red,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            final isDifferentMonth = day.month != focusedDay.month;
            if (isDifferentMonth) {
              return _buildDifferentMonthDay(day, calendarColors);
            }

            final isEventDay = _events.values
                .expand((eventList) => eventList)
                .any((event) {
                  try {
                    final eventDate = event.startDate;
                    return isSameDay(eventDate, day);
                  } catch (e) {
                    return false;
                  }
                });

            final isWeekend = _isWeekend(day);
            final hasUserEvent = _events.values
                .expand((eventList) => eventList)
                .where((event) {
                  try {
                    final eventDate = event.startDate;
                    return isSameDay(eventDate, day);
                  } catch (e) {
                    return false;
                  }
                })
                .any((event) => event.userId == _currentUserId);

            return Center(
              child: Container(
                decoration: BoxDecoration(
                  color:
                      hasUserEvent
                          ? calendarColors.userBackground
                          : (isEventDay
                              ? calendarColors.otherUserBackground
                              : null),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    day.day.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      color:
                          isWeekend
                              ? (isDarkMode ? Colors.red[200] : Colors.red)
                              : (hasUserEvent
                                  ? calendarColors.userFont
                                  : (isEventDay
                                      ? calendarColors.otherUserFont
                                      : Theme.of(
                                        context,
                                      ).colorScheme.onSurface)),
                    ),
                  ),
                ),
              ),
            );
          },
          todayBuilder: (context, day, focusedDay) {
            final isDifferentMonth = day.month != focusedDay.month;
            if (isDifferentMonth) {
              return _buildDifferentMonthDay(day, calendarColors);
            }

            final isEventDay = _events.values
                .expand((eventList) => eventList)
                .any((event) {
                  try {
                    final eventDate = event.startDate;
                    return isSameDay(eventDate, day);
                  } catch (e) {
                    return false;
                  }
                });

            final isWeekend = _isWeekend(day);
            final hasUserEvent = _events.values
                .expand((eventList) => eventList)
                .where((event) {
                  try {
                    final eventDate = event.startDate;
                    return isSameDay(eventDate, day);
                  } catch (e) {
                    return false;
                  }
                })
                .any((event) => event.userId == _currentUserId);

            return Center(
              child: Container(
                decoration: BoxDecoration(
                  color:
                      hasUserEvent
                          ? calendarColors.userBackground
                          : (isEventDay
                              ? calendarColors.otherUserBackground
                              : calendarColors.todayEventBackground),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    day.day.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:
                          isWeekend
                              ? (isDarkMode ? Colors.red[200] : Colors.red)
                              : (hasUserEvent
                                  ? calendarColors.userFont
                                  : (isEventDay
                                      ? calendarColors.otherUserFont
                                      : calendarColors.todayEventFont)),
                    ),
                  ),
                ),
              ),
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            final isDifferentMonth = day.month != focusedDay.month;
            if (isDifferentMonth) {
              return _buildDifferentMonthDay(
                day,
                calendarColors,
                isSelected: true,
              );
            }

            final isEventDay = _events.values
                .expand((eventList) => eventList)
                .any((event) {
                  try {
                    final eventDate = event.startDate;
                    return isSameDay(eventDate, day);
                  } catch (e) {
                    return false;
                  }
                });

            final hasUserEvent = _events.values
                .expand((eventList) => eventList)
                .where((event) {
                  try {
                    final eventDate = event.startDate;
                    return isSameDay(eventDate, day);
                  } catch (e) {
                    return false;
                  }
                })
                .any((event) => event.userId == _currentUserId);

            return Center(
              child: Container(
                decoration: BoxDecoration(
                  color:
                      hasUserEvent
                          ? calendarColors.userBackground
                          : (isEventDay
                              ? calendarColors.otherUserBackground
                              : calendarColors.selectedEventBackground),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    day.day.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      color: calendarColors.selectedEventFont,
                    ),
                  ),
                ),
              ),
            );
          },
          outsideBuilder: (context, day, focusedDay) {
            return _buildDifferentMonthDay(day, calendarColors);
          },
        ),
        daysOfWeekHeight: 40,
        rowHeight: dayBoxHeight,
      ),
    );
  }

  Widget _buildDifferentMonthDay(
    DateTime day,
    CalendarColors calendarColors, {
    bool isSelected = false,
  }) {
    final isWeekend = _isWeekend(day);

    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: calendarColors.differentMonthBackground,
        ),
        child: Center(
          child: Text(
            day.day.toString(),
            style: TextStyle(
              fontSize: 18,
              color:
                  isWeekend
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? Colors.red[300]!
                          : Colors.red[300]!)
                      : calendarColors.differentMonthFont,
            ),
          ),
        ),
      ),
    );
  }

  bool _isWeekend(DateTime day) {
    return day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
  }

  void _showDayOverlay(DateTime selectedDay, BuildContext context) {
    _removeOverlay();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: Navigator.of(context),
    );

    final screenSize = MediaQuery.of(context).size;
    final dayEvents =
        _events.values.expand((eventList) => eventList).where((event) {
          try {
            final eventDate = event.startDate;
            return isSameDay(eventDate, selectedDay);
          } catch (e) {
            return false;
          }
        }).toList();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: _removeOverlay,
              child: Container(
                color: const Color.fromARGB(28, 0, 0, 0),
                width: screenSize.width,
                height: screenSize.height,
              ),
            ),
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _animationController!,
                  curve: Curves.easeOutBack,
                ),
                child: FadeTransition(
                  opacity: _animationController!,
                  child: Material(
                    elevation: 8.0,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: screenSize.width * 0.8,
                      height: screenSize.height * 0.8,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Selected Day',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            DateFormat.yMMMMd().format(selectedDay),
                            style: TextStyle(fontSize: 18),
                          ),
                          // SizedBox(height: 30, child: Text("Hey")),
                          if (dayEvents.isNotEmpty) ...[
                            Text(
                              'Events:',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            Expanded(
                              child: ListView.builder(
                                itemCount: dayEvents.length,
                                itemBuilder: (context, index) {
                                  final event = dayEvents[index];
                                  final isUserEvent =
                                      event.userId == _currentUserId;
                                  return ListTile(
                                    leading:
                                        isUserEvent
                                            ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 40, // Increased width
                                                  child: IconButton(
                                                    icon: Icon(
                                                      Icons.edit,
                                                      size:
                                                          24, // Increased size
                                                    ),
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                    onPressed: () {
                                                      _removeOverlay();
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder:
                                                              (
                                                                context,
                                                              ) => UpdateEventScreen(
                                                                event: event,
                                                                updateCallback:
                                                                    _updateEventViaWebSocket,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 40, // Increased width
                                                  child: IconButton(
                                                    icon: Icon(
                                                      Icons.delete,
                                                      size:
                                                          24, // Increased size
                                                      color: Colors.red,
                                                    ),
                                                    onPressed: () {
                                                      _removeOverlay();
                                                      showDialog(
                                                        context: context,
                                                        builder:
                                                            (
                                                              context,
                                                            ) => AlertDialog(
                                                              title: Text(
                                                                'Delete Event',
                                                              ),
                                                              content: Text(
                                                                'Are you sure you want to delete this event?',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                      ),
                                                                  child: Text(
                                                                    'Cancel',
                                                                  ),
                                                                ),
                                                                ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor:
                                                                        Colors
                                                                            .red,
                                                                  ),
                                                                  onPressed: () {
                                                                    _deleteEventViaWebSocket(
                                                                      event.id,
                                                                      event,
                                                                    );
                                                                    Navigator.pop(
                                                                      context,
                                                                    );
                                                                  },
                                                                  child: Text(
                                                                    'Delete',
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            )
                                            : SizedBox(width: 60),
                                    title: Container(
                                      width: double.infinity,
                                      child: Text(
                                        event.title ?? 'No Title',
                                        style: TextStyle(
                                          fontSize: 18, // Larger font size
                                          fontWeight: FontWeight.bold, // Bold
                                        ),
                                      ),
                                    ),
                                    subtitle: Container(
                                      width: double.infinity,
                                      child: Text(
                                        event.description ?? 'No Description',
                                        style: TextStyle(
                                          fontSize: 14, // Smaller font size
                                          color: Colors.grey[600], // Grey color
                                        ),
                                      ),
                                    ),
                                    trailing: SizedBox(
                                      width: 30, // Increased width
                                      child: Icon(
                                        Icons.event,
                                        size: 24, // Increased size
                                        color:
                                            isUserEvent
                                                ? Colors.orange
                                                : Colors.green,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ] else
                            Text(
                              'No events for this day',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 15,
                              ),
                            ),
                            onPressed: _removeOverlay,
                            child: Text(
                              'Close',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          SizedBox(height: 20),
                          FloatingActionButton(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            onPressed: () {
                              _removeOverlay();
                              print(
                                "_currentUserId_currentUserId_currentUserId",
                              );
                              print(_currentUserId);
                              final newEvent = {
                                "userId": _currentUserId,
                                "title": _newEventTitle,
                                "start_date": DateFormat(
                                  "dd-MM-yyyy",
                                ).format(selectedDay),
                                "description": _newEventDescription,
                                "end_date": DateFormat(
                                  "dd-MM-yyyy",
                                ).format(selectedDay),
                              };
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => CreateEventScreen(
                                        event: newEvent,
                                        createCallback:
                                            _createEventViaWebSocket,
                                      ),
                                ),
                              );
                            },
                            child: Icon(Icons.add),
                            tooltip: "Add Event",
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
    _animationController!.forward();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _removeOverlay();
    _animationController?.dispose(); // Add this if not already present
    super.dispose();
  }
}
