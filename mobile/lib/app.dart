import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/ws/ws_client.dart';
import 'features/connection/connection_screen.dart';
import 'features/connection/connection_cubit.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => WsClient(),
      child: BlocProvider(
        create: (ctx) => ConnectionCubit(ctx.read<WsClient>()),
        child: MaterialApp(
          title: 'Оптимизатор BBO',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.light,
            useMaterial3: true,
          ),
          home: const ConnectionScreen(),
        ),
      ),
    );
  }
}
