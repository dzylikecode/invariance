import 'package:material_ui/material_ui.dart';
import 'package:project_xmake/project_xmake.dart';

void main() => runApp(const MyApp());

class const MyApp({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: Scaffold(body: Center(child: Text('${add(1, 2)}'))),
    );
  }
}
