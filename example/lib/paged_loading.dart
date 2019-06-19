import 'dart:math';

import 'package:async_controller/async_controller.dart';
import 'package:flutter/material.dart';

import 'helpers.dart';

/// Utility to mock paged data loading with various situations.
class FakePageDataProvider {
  final int totalCount;
  final int errorChance;

  FakePageDataProvider(this.totalCount, {this.errorChance = 0});

  Future<PagedData<String>> fetchPage(int index, int pageSize) async {
    await Future.delayed(Duration(milliseconds: 500));

    if (errorChance > Random().nextInt(100)) {
      throw 'Random failure';
    }

    final count = min(totalCount, index + pageSize) - index;
    final list = Iterable.generate(count, (i) => 'Item ${index + i + 1}').toList();

    print('fetchPage, ${list.length} items');
    return PagedData(index, totalCount, list);
  }
}

class PagedLoadingPage extends StatefulWidget with ExamplePage {
  @override
  String get title => 'Paged data';

  @override
  _PagedLoadingPageState createState() => _PagedLoadingPageState();
}

class _PagedLoadingPageState extends State<PagedLoadingPage> {
  final _decorator = PagedListDecoration(
    noDataContent: Text('Sorry, no data'),
    addRefreshIndicator: true,
  );

  final cases = [
    TitledValue('Always works', PagedAsyncController(FakePageDataProvider(25).fetchPage)),
    TitledValue('No content', PagedAsyncController(FakePageDataProvider(0).fetchPage)),
    TitledValue('Always error', PagedAsyncController(FakePageDataProvider(0, errorChance: 100).fetchPage)),
    TitledValue('Sometimes error', PagedAsyncController(FakePageDataProvider(1000, errorChance: 80).fetchPage)),
  ];

  @override
  Widget build(BuildContext context) {
    return CasePicker<PagedAsyncController>(
      appBar: widget.buildAppBar(),
      cases: cases,
      builder: buildCase,
    );
  }

  Widget buildCase(BuildContext context, PagedAsyncController _controller) {
    return _controller.buildAsync(
      decorator: _decorator,
      builder: (_, data) {
        var count = data.length;
        if (!_controller.hasAll) {
          count += 1;
        }

        return ListView.builder(
          itemCount: count,
          itemBuilder: (context, i) {
            if (i >= data.length) {
              return PagedListLoadMoreTile();
            }

            _controller.markAccess(i);
            return ListTile(title: Text(data[i]));
          },
        );
      },
    );
  }
}
