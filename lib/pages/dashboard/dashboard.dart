import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final TextEditingController _textController = TextEditingController();
  String _result = "";

  Future<void> _analyzeText(String text) async {
    final url = Uri.parse(
        "https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze?key=AIzaSyCBB_EvhOp1cVvagQNaHy9cnpcb2fYe2gg");
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'comment': {'text': text},
        'languages': ['en'],
        'requestedAttributes': {'TOXICITY': {}},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final score =
          data['attributeScores']['TOXICITY']['summaryScore']['value'];
      setState(() {
        _result = "Toxicity Score: ${(score * 100).toStringAsFixed(2)}%";
      });
    } else {
      setState(() {
        _result = "Error analyzing text.";
      });
    }
  }

  Future<void> _saveToFirestore(String text, String result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('analysis_history').add({
          'uid': user.uid,
          'text': text,
          'result': result,
          'timestamp': FieldValue.serverTimestamp(),
        });
        // print("Data added successfully!");
      } catch (e) {
        // print("Error adding data: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: const Color(0xff0D6EFD),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: "Enter text for sentiment analysis",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_textController.text.isNotEmpty) {
                  _analyzeText(_textController.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0D6EFD),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Analyze"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_textController.text.isNotEmpty && _result.isNotEmpty) {
                  _saveToFirestore(_textController.text, _result);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Save"),
            ),
            const SizedBox(height: 20),
            Text(
              _result,
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
            const SizedBox(height: 20),
            const Text(
              "History:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('analysis_history')
                    .where('uid',
                        isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    // .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No history found."));
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['text'] ?? ""),
                        subtitle: Text(data['result'] ?? ""),
                        trailing: Text(data['timestamp'] != null
                            ? (data['timestamp'] as Timestamp)
                                .toDate()
                                .toString()
                            : ""),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
