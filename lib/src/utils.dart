import 'package:flutter/widgets.dart';

class AsyncPropertyBuilder<P> extends StatefulWidget {
  final Listenable listenable;
  final P Function() selector;
  final Widget Function(BuildContext, P) builder;

  const AsyncPropertyBuilder({Key key, this.selector, this.builder, this.listenable}) : super(key: key);

  @override
  _AsyncPropertyBuilderState createState() => _AsyncPropertyBuilderState();
}

class _AsyncPropertyBuilderState<P> extends State<AsyncPropertyBuilder<P>> {
  P _current;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(AsyncPropertyBuilder<P> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listenable != oldWidget.listenable) {
      oldWidget.listenable.removeListener(_handleChange);
      widget.listenable.addListener(_handleChange);
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    final now = widget.selector();
    if (now != _current) {
      setState(() {
        _current = now;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _current);
  }
}
