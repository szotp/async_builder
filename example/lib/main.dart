import 'dart:async';

import 'package:async/async.dart';
import 'package:example/helpers.dart';
import 'package:example/huge_list_page.dart';
import 'package:example/paged_loading.dart';
import 'package:example/refreshers_page.dart';
import 'package:example/sort_and_search.dart';
import 'package:flutter/material.dart';

import 'async_button_example.dart';
import 'failure_handling.dart';
import 'minimal.dart';
import 'pull_to_refresh.dart';
import 'translator/translator_page.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ExampleSwitcher(),
    );
  }
}

Stream<List<int>> lol() {
  final ctr = StreamController<List<int>>();
  ctr.add([1]);
  ctr.addError('xxx');
  ctr.close();
  return ctr.stream;
}

Stream<int> lol2() {
  return lol().expand((x) => x);
}

Future<List<int>> collect() async {
  final stream = StreamQueue(lol2());
  while (true) {
    final got = await stream.take(1);
    print('got');
    if (got.length == 0) {
      break;
    }
  }

  return [];
}

class ExampleSwitcher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final examples = <ExamplePage>[
      MinimalExample(),
      PullToRefreshPage(),
      FailureHandlingPage(),
      PagedLoadingPage(),
      SortAndSearchPage(),
      AsyncButtonPage(),
      RefreshersPage(),
      TranslatorPage(),
      HugeListPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('async_controller'),
      ),
      body: ListView.builder(
        itemCount: examples.length,
        itemBuilder: (context, i) {
          final example = examples[i];
          return ListTile(
            title: Text(example.title),
            onTap: () {
              final route = MaterialPageRoute(builder: (context) => examples[i]);
              Navigator.of(context).push(route);
            },
          );
        },
      ),
    );
  }
}
