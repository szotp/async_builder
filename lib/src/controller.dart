import 'dart:async';

import 'package:async_controller/async_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'refreshers.dart';

/// Object created for every fetch to control cancellation.
class AsyncFetchItem {
  static const cancelledError = 'cancelled';
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  /// Waits until feature is finished, and then ensures that fetch was not cancelled
  Future<T> ifNotCancelled<T>(Future<T> future) async {
    final result = await future;
    if (isCancelled) {
      throw cancelledError;
    }

    return result;
  }

  Future<void> _runningFuture;

  static Future<void> runFetch(AsyncControllerFetchExpanded<void> fetch) {
    final status = AsyncFetchItem();
    status._runningFuture = fetch(status);

    return status._runningFuture.catchError((dynamic error) {
      assert(error == cancelledError, '$error');
    });
  }
}

enum AsyncControllerState {
  /// Controller was just created and there is nothing to show.
  /// Usually loading indicator will be shown in this case. data == nil, error == nil
  noDataYet,

  /// The fetch was successful, and we have something to show. data.isNotEmpty
  hasData,

  /// The fetch was successful, but there is nothing to show. data == nil || data.isEmpty
  noData,

  /// Fetch failed. error != nil
  failed,
}

/// Simplified fetch function that does not care about cancellation.
typedef AsyncControllerFetch<T> = Future<T> Function();
typedef AsyncControllerFetchExpanded<T> = Future<T> Function(
    AsyncFetchItem status);

/// A controller for managing asynchronously loading data.
abstract class AsyncController<T> extends ChangeNotifier
    implements ValueListenable<T>, Refreshable {
  AsyncController();

  factory AsyncController.method(AsyncControllerFetch<T> method) {
    return _SimpleAsyncController(method);
  }

  // prints errors in debug mode, ensures that they are not programmer's mistake
  static bool debugCheckErrors = true;

  /// _version == 0 means that there was no fetch yet
  int _version = 0;
  T _value;
  Object _error;
  bool _isLoading = false;

  AsyncFetchItem _lastFetch;

  /// Behaviors dictate when loading controller needs to reload.
  final List<LoadingRefresher> _behaviors = [];

  @override
  T get value => _value;

  Object get error => _error;
  bool get isLoading => _isLoading;

  /// Number of finished fetches since last reset.
  int get version => _version;

  AsyncControllerState get state {
    if (hasData) {
      return AsyncControllerState.hasData;
    } else if (error != null && !isLoading) {
      return AsyncControllerState.failed;
    } else if (version == 0) {
      return AsyncControllerState.noDataYet;
    } else {
      return AsyncControllerState.noData;
    }
  }

  @override
  void setNeedsRefresh(SetNeedsRefreshFlag flags) {
    if (flags == SetNeedsRefreshFlag.ifError && error == null) {
      return;
    }

    if (flags == SetNeedsRefreshFlag.ifNotLoading && isLoading) {
      return;
    }

    if (flags == SetNeedsRefreshFlag.reset) {
      reset();
      return;
    }

    _cancelCurrentFetch();
    if (hasListeners) {
      _internallyLoadAndNotify();
    }
  }

  void _cancelCurrentFetch([AsyncFetchItem nextFetch]) {
    _lastFetch?._isCancelled = true;
    _lastFetch = nextFetch;
  }

  /// Clears all stored data. Will fetch again if controller has listeners.
  Future<void> reset() {
    _version = 0;
    _cancelCurrentFetch();
    _value = null;
    _error = null;
    _isLoading = false;

    if (hasListeners) {
      return _internallyLoadAndNotify();
    } else {
      return Future<void>.value();
    }
  }

  /// Indicates if controller has data that could be displayed.
  bool get hasData => _value != null;

  @protected
  Future<T> fetch(AsyncFetchItem status);

  Future<void> _internallyLoadAndNotify() {
    return AsyncFetchItem.runFetch((status) async {
      _cancelCurrentFetch(status);

      if (!_isLoading || error != null) {
        _isLoading = true;
        _error = null;

        // microtask avoids crash that would happen when executing loadIfNeeded from build method
        Future.microtask(notifyListeners);
      }

      try {
        final value = await status.ifNotCancelled(fetch(status));

        _value = value;
        _version += 1;
        _error = null;
      } catch (e) {
        if (e == AsyncFetchItem.cancelledError) {
          return;
        }

        if (kDebugMode && AsyncController.debugCheckErrors) {
          // this is disabled in production code and behind a flag
          // ignore: avoid_print
          print('${this} got error:\n$e');

          assert(e is! NoSuchMethodError, '$e');
        }

        _error = e;
      }

      _isLoading = false;
      notifyListeners();
    });
  }

  /// Notify that currently held value changed without doing new fetch.
  @protected
  void internallyUpdateVersion() {
    assert(_version > 0,
        'Attempted to raise version on empty controller. Something needs to be loaded.');
    _version++;
    notifyListeners();
  }

  Future<void> performUserInitiatedRefresh() {
    return _internallyLoadAndNotify();
  }

  /// This future never fails - there is no need to catch.
  /// If there is error during loading it will handled by the controller.
  /// If multiple widgets call this method, they will get the same future.
  Future<void> loadIfNeeded() {
    if (_lastFetch == null) {
      _internallyLoadAndNotify();
    }
    return _lastFetch._runningFuture;
  }

  /// Adds loading refresher that will have capability to trigger a reload of controller.
  void addRefresher(LoadingRefresher behavior) {
    behavior.mount(this);
    _behaviors.add(behavior);

    if (hasListeners) {
      behavior.activate();
    }
  }

  @protected
  void activate() {
    for (final b in _behaviors) {
      b.activate();
    }
    loadIfNeeded();
  }

  @protected
  void deactivate() {
    for (final b in _behaviors) {
      b.deactivate();
    }
  }

  @override
  void addListener(void Function() listener) {
    if (!hasListeners) {
      activate();
    }
    super.addListener(listener);
  }

  @override
  void removeListener(void Function() listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      deactivate();
    }
  }

  @override
  void dispose() {
    if (hasListeners) {
      deactivate();
    }
    super.dispose();
  }
}

class _SimpleAsyncController<T> extends AsyncController<T> {
  _SimpleAsyncController(this.method);

  final AsyncControllerFetch<T> method;

  @override
  Future<T> fetch(AsyncFetchItem status) => method();
}

/// A controller that does additonal processing after fetching base data.
/// Useful for local filtering, sorting, etc.
abstract class MappedAsyncController<BaseValue, MappedValue>
    extends AsyncController<MappedValue> {
  Future<BaseValue> fetchBase();

  /// A method that runs after expensive base fetch. Call setNeedsLocalTransform if conditions affecting the transform has changed.
  /// For example if searchText for locally implemented search has changed.
  Future<MappedValue> transform(BaseValue data);

  Future<BaseValue> _cachedBase;

  @override
  Future<MappedValue> fetch(AsyncFetchItem status) async {
    _cachedBase ??= fetchBase();

    try {
      return transform(await _cachedBase);
    } catch (e) {
      _cachedBase = null;
      rethrow;
    }
  }

  @override
  Future<void> performUserInitiatedRefresh() {
    _cachedBase = null;
    return super.performUserInitiatedRefresh();
  }

  /// Re-run fetch on existing cached base
  @protected
  void setNeedsLocalTransform() {
    _internallyLoadAndNotify();
  }
}

/// A controller that loads a list and then removes some items from it.
abstract class FilteringAsyncController<Value>
    extends MappedAsyncController<List<Value>, List<Value>> {
  @override
  bool get hasData => super.hasData && value.isNotEmpty;
}
