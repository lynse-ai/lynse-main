// import 'package:flutter/material.dart';
// import 'package:dio_log/dio_log.dart';

// class DioLogFloat extends StatelessWidget {
//   const DioLogFloat({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<List<Widget>>(
//       future: _buildDioLog(context),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.done) {
//           if (snapshot.hasData) {
//             return Column(children: snapshot.data!);
//           }
//         }
//         return const SizedBox.shrink();
//       },
//     );
//   }

//   Future<List<Widget>> _buildDioLog(BuildContext context) async {
//     return [
//       // Display overlay button
//       await showDebugBtn(context, btnColor: Colors.blue) as Widget,
//       // Cancel overlay button
//       await dismissDebugBtn() as Widget,
//     ];
//   }
// }
