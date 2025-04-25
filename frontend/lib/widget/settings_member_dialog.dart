import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/providers/folder_provider.dart';
import 'package:frontend/providers/room_provider.dart';
import 'package:frontend/providers/roomdb_provider.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import '../providers/paper_provider.dart';
import '../providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsMember extends StatefulWidget {
  final String roomId;
  final String originalId;
  final String roomName;

  const SettingsMember(
      {Key? key,
      required this.roomId,
      required this.originalId,
      required this.roomName})
      : super(key: key);

  @override
  _SettingsMemberState createState() => _SettingsMemberState();
}

class _SettingsMemberState extends State<SettingsMember> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _originalMembers = [];
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _loadMembers() async {
    final roomProvider = Provider.of<RoomDBProvider>(context, listen: false);
    final members = await roomProvider.loadMembers(widget.roomId);
    setState(() {
      _members = members.map((m) => Map<String, dynamic>.from(m)).toList();
      _originalMembers =
          members.map((m) => Map<String, dynamic>.from(m)).toList();
      _hasChanges = false;
    });
  }

  void _checkForChanges() {
    for (int i = 0; i < _members.length; i++) {
      print(
          "Comparing: ${_members[i]['role']} with ${_originalMembers[i]['role']}");
      if (_members[i]['role'].toLowerCase() !=
          _originalMembers[i]['role'].toLowerCase()) {
        print("Found a change!");
        setState(() => _hasChanges = true);
        return;
      }
    }
    setState(() => _hasChanges = false);
  }

  void _saveChanges() {
    // TODO: Send updated _members to the backend
    print("Saving changes: $_members");
    Provider.of<RoomDBProvider>(context, listen: false)
        .updateMemberRole(widget.roomId, widget.originalId, _members);

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Update Member successfully')),
    );
    setState(() {
      _originalMembers = List<Map<String, dynamic>>.from(_members);
      _hasChanges = false;
    });
  }

  Future<void> _confirmDeleteMember(int index) async {
    final email = _members[index]['email'];

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Removal'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to remove $email from this room?'),
                const SizedBox(height: 10),
                const Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                // Proceed with deletion
                RoomDBProvider roomProvider =
                    Provider.of<RoomDBProvider>(context, listen: false);
                roomProvider.deleteMember(
                  widget.roomId,
                  _members[index]['email'],
                );
                setState(() {
                  _members.removeAt(index);
                });
                _checkForChanges();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print("roomId : ${widget.roomId}");

    return AlertDialog(
      title: Text('${widget.roomName} Members'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_members.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...List.generate(_members.length, (index) {
                final member = _members[index];
                final isOwner = member['role'] == 'owner';
                return ListTile(
                  dense: true,
                  title: Text(_members[index]['email']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 120,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _members[index]['role'],
                          onChanged: isOwner
                              ? null
                              : (String? newRole) {
                                  if (newRole != null && newRole != 'owner') {
                                    print(
                                        "Changing role from ${_members[index]['role']} to $newRole");
                                    setState(() {
                                      _members[index]['role'] = newRole;
                                    });
                                    _checkForChanges();
                                  }
                                },
                          items: (isOwner ? ['owner'] : ['write', 'read'])
                              .map((role) {
                            return DropdownMenuItem<String>(
                              value: role,
                              child: Text(
                                role[0].toUpperCase() + role.substring(1),
                                style: TextStyle(
                                  color: isOwner ? Colors.grey : Colors.black,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      IconButton(
                        icon: isOwner
                            ? const SizedBox.shrink()
                            : const Icon(Icons.delete),
                        onPressed: isOwner
                            ? null
                            : () => _confirmDeleteMember(
                                index), // Call confirmation dialog
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _hasChanges
              ? _saveChanges
              : null, // Disables button if no changes
          style: ElevatedButton.styleFrom(
            backgroundColor: _hasChanges ? Colors.blue : Colors.grey,
            textStyle: _hasChanges
                ? const TextStyle(color: Colors.white)
                : const TextStyle(color: Colors.black),
          ),
          child: const Text('Save'),
        )
      ],
    );
  }
}
