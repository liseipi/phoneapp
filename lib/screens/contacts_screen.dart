import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import '../providers/contact_provider.dart';
import '../providers/call_provider.dart';
import '../models/contact.dart';
import 'call_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通讯录'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索联系人',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                context.read<ContactProvider>().searchContacts(value);
              },
            ),
          ),

          // 联系人列表
          Expanded(
            child: Consumer<ContactProvider>(
              builder: (context, contactProvider, child) {
                if (contactProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (contactProvider.contacts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.contacts_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无联系人',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            contactProvider.loadContacts();
                          },
                          child: const Text('刷新'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: contactProvider.contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contactProvider.contacts[index];
                    return _ContactTile(contact: contact);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.read<ContactProvider>().loadContacts();
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;

  const _ContactTile({required this.contact});

  Future<void> _makeCall(BuildContext context) async {
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    
    // 导航到通话界面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          phoneNumber: contact.phoneNumber,
          contactName: contact.name,
        ),
      ),
    );

    // 启动通话
    await callProvider.startCall(
      contact.phoneNumber,
      contactName: contact.name,
    );
    
    // 实际拨打电话
    await FlutterPhoneDirectCaller.callNumber(contact.phoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          contact.initials,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        contact.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(contact.phoneNumber),
      trailing: IconButton(
        icon: const Icon(Icons.phone),
        color: Colors.green,
        onPressed: () => _makeCall(context),
      ),
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => _ContactDetailSheet(contact: contact),
        );
      },
    );
  }
}

class _ContactDetailSheet extends StatelessWidget {
  final Contact contact;

  const _ContactDetailSheet({required this.contact});

  Future<void> _makeCall(BuildContext context) async {
    Navigator.pop(context); // 关闭底部表单
    
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    
    // 导航到通话界面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          phoneNumber: contact.phoneNumber,
          contactName: contact.name,
        ),
      ),
    );

    // 启动通话
    await callProvider.startCall(
      contact.phoneNumber,
      contactName: contact.name,
    );
    
    // 实际拨打电话
    await FlutterPhoneDirectCaller.callNumber(contact.phoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              contact.initials,
              style: TextStyle(
                fontSize: 32,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            contact.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            contact.phoneNumber,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _makeCall(context),
              icon: const Icon(Icons.phone),
              label: const Text('拨打电话'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
