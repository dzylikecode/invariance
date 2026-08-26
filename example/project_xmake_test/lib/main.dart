import 'package:material_ui/material_ui.dart';
import 'package:project_xmake/project_xmake.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: Scaffold(body: Center(child: Text('${add(1, 2)}'))),
    );
  }
}
