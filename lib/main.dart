import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class ClientInfo {
  String id;
  String ip;

  ClientInfo(this.id, this.ip);
}

class Message {
  String clientId;
  String clientIp;
  String text;

  Message(this.clientId, this.clientIp, this.text);
}

class _MyHomePageState extends State<MyHomePage> {
  WebSocketChannel? _channel;
  HttpServer? _server;
  bool _isServerRunning = false;
  List<ClientInfo> _clientsInfo = [];
  List<Message> _messages = [];

  @override
  void dispose() {
    _channel?.sink?.close();
    _server?.close();
    super.dispose();
  }

  void _startServer() async {
    try {
      _server = await HttpServer.bind("192.168.1.5", 8080);
      _server!.listen((HttpRequest request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          _handleConnection(request);
        }
      });
      setState(() {
        _isServerRunning = true;
      });
      print('WebSocket server started on port 8080');
    } catch (e) {
      print('Error starting server: $e');
    }
  }

  void _stopServer() {
    _server?.close();
    _server = null;
    setState(() {
      _isServerRunning = false;
    });
    print('WebSocket server stopped');
  }

  void _handleConnection(HttpRequest request) async  {
    final socket =await WebSocketTransformer.upgrade(request);
    final clientId = socket.hashCode.toString();
    final clientIp = request.headers.value('X-Forwarded-For') ??
        request.connectionInfo!.remoteAddress.address;

    _clientsInfo.add(ClientInfo(clientId, clientIp));
    setState(() {});

     socket.listen(
    (message) {
      print('Received: $message');

      _messages.add(Message(clientId, clientIp, message));
      setState(() {});

      // Echo the message back to the client
      socket.add('You sent: $message');
    },
    onDone: () {
      print('Client disconnected');
      _clientsInfo.removeWhere((client) => client.id == clientId);
      setState(() {});
    },
  );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebSocket Server'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _isServerRunning ? 'Server Running' : 'Server Stopped',
              style: TextStyle(fontSize: 20),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _clientsInfo.length,
              itemBuilder: (BuildContext context, int index) {
                final client = _clientsInfo[index];
                return ListTile(
                  title: Text('Client ID: ${client.id}'),
                  subtitle: Text('IP: ${client.ip}'),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                final message = _messages[index];
                return ListTile(
                  title: Text('Client ID: ${message.clientId}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IP: ${message.clientIp}'),
                      Text('Message: ${message.text}'),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isServerRunning ? _stopServer : _startServer,
            child: Text(_isServerRunning ? 'Stop Server' : 'Start Server'),
          ),
        ],
      ),
    );
  }
}
