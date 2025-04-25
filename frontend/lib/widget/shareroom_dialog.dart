import 'package:flutter/material.dart';
import 'package:frontend/api/apiService.dart';
import 'package:frontend/providers/folder_provider.dart';
import 'package:frontend/providers/room_provider.dart';
import 'package:frontend/providers/roomdb_provider.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import '../providers/paper_provider.dart';
import '../providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShareDialog extends StatefulWidget {
  final String roomId;
  final String roomName;
  final bool? isCollab;

  const ShareDialog(
      {Key? key,
      required this.roomId,
      required this.roomName,
      required this.isCollab})
      : super(key: key);

  @override
  _ShareDialogState createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _permission = 'read';
  List<String> _sharedWith = [];
  bool _isSharing = false;
  List<Map<String, dynamic>> _members = [];

  void _loadMembers() async {
    final roomProvider = Provider.of<RoomDBProvider>(context, listen: false);
    final members = await roomProvider.loadMembers(widget.roomId);
    setState(() {
      _members = members.map((m) => Map<String, dynamic>.from(m)).toList();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _addEmail() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _sharedWith.add(_emailController.text.trim());
        _emailController.clear();
      });
    }
  }

  void _removeEmail(String email) {
    setState(() {
      _sharedWith.remove(email);
    });
  }

  Future<void> _shareRoom() async {
    if (_sharedWith.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one user to share with'),
        ),
      );
      return;
    }

    setState(() {
      _isSharing = true;
    });

    if (widget.isCollab == true) {
      try {
        ApiService apiService = ApiService();
        apiService.shareMember(
            roomId: widget.roomId,
            sharedWith: _sharedWith,
            permission: _permission);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room shared successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share room: $e')));
      } finally {
        setState(() {
          _isSharing = false;
        });
      }
    } else {
      try {
        final roomProvider = Provider.of<RoomProvider>(context, listen: false);
        final folderProvider =
            Provider.of<FolderProvider>(context, listen: false);
        final fileProvider = Provider.of<FileProvider>(context, listen: false);

        print("Roomid dialog : ${widget.roomId}");

        await roomProvider.shareRoom(widget.roomId, _sharedWith, _permission,
            folderProvider, fileProvider);

        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room shared & cloned successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share room: $e')));
      } finally {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is logged in
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoggedIn = authProvider.isLoggedIn;
    if (widget.isCollab == true) {
      _loadMembers();
    }

    if (!isLoggedIn) {
      return AlertDialog(
        title: const Text('Login Required'),
        content: const Text('You need to be logged in to share rooms.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/login');
            },
            child: const Text('Login'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text('Share "${widget.roomName}"'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter email to share with',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addEmail,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  if (value == authProvider.email) {
                    return "You cannot share a room with yourself!";
                  }
                  for (var member in _members) {
                    if (member['email'] == value) {
                      return 'This email is already a member of the room';
                    }
                  }
                  for (var email in _sharedWith) {
                    if (email == value) {
                      return 'This email is already added';
                    }
                  }
                  return null;
                },
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            const SizedBox(height: 16),
            if (_sharedWith.isNotEmpty) ...[
              const Text('Shared with:'),
              const SizedBox(height: 8),
              ...List.generate(_sharedWith.length, (index) {
                return ListTile(
                  dense: true,
                  title: Text(_sharedWith[index]),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => _removeEmail(_sharedWith[index]),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            const Text('Permission:'),
            RadioListTile<String>(
              title: const Text('Read only'),
              value: 'read',
              groupValue: _permission,
              onChanged: (value) {
                setState(() {
                  _permission = value!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Read and write'),
              value: 'write',
              groupValue: _permission,
              onChanged: (value) {
                setState(() {
                  _permission = value!;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSharing ? null : _shareRoom,
          child: _isSharing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Share'),
        ),
      ],
    );
  }
}
