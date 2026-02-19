import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/providers/app_state.dart';

void main() {
  group('AppState Base Classes', () {
    test('InitialState has no props', () {
      const state = InitialState();
      expect(state.props, isEmpty);
    });

    test('InitialState instances are equal', () {
      const state1 = InitialState();
      const state2 = InitialState();
      expect(state1, equals(state2));
    });

    test('LoadingState with no message', () {
      const state = LoadingState();
      expect(state.message, isNull);
      expect(state.props, [null]);
    });

    test('LoadingState with message', () {
      const state = LoadingState(message: 'Loading data...');
      expect(state.message, 'Loading data...');
      expect(state.props, ['Loading data...']);
    });

    test('LoadingState instances with same message are equal', () {
      const state1 = LoadingState(message: 'Loading');
      const state2 = LoadingState(message: 'Loading');
      expect(state1, equals(state2));
    });

    test('LoadingState instances with different messages are not equal', () {
      const state1 = LoadingState(message: 'Loading A');
      const state2 = LoadingState(message: 'Loading B');
      expect(state1, isNot(equals(state2)));
    });

    test('ErrorState with message only', () {
      const state = ErrorState('Something went wrong');
      expect(state.message, 'Something went wrong');
      expect(state.exception, isNull);
      expect(state.props, ['Something went wrong', null]);
    });

    test('ErrorState with message and exception', () {
      final exception = Exception('Test error');
      final state = ErrorState('Failed', exception: exception);
      expect(state.message, 'Failed');
      expect(state.exception, exception);
      expect(state.props, ['Failed', exception]);
    });

    test('ErrorState instances with same values are equal', () {
      const state1 = ErrorState('Error');
      const state2 = ErrorState('Error');
      expect(state1, equals(state2));
    });

    test('ErrorState instances with different messages are not equal', () {
      const state1 = ErrorState('Error A');
      const state2 = ErrorState('Error B');
      expect(state1, isNot(equals(state2)));
    });

    test('SuccessState with data only', () {
      const state = SuccessState<String>('test data');
      expect(state.data, 'test data');
      expect(state.message, isNull);
      expect(state.props, ['test data', null]);
    });

    test('SuccessState with data and message', () {
      const state = SuccessState<int>(42, message: 'Success!');
      expect(state.data, 42);
      expect(state.message, 'Success!');
      expect(state.props, [42, 'Success!']);
    });

    test('SuccessState instances with same values are equal', () {
      const state1 = SuccessState<String>('data');
      const state2 = SuccessState<String>('data');
      expect(state1, equals(state2));
    });

    test('SuccessState instances with different data are not equal', () {
      const state1 = SuccessState<String>('data1');
      const state2 = SuccessState<String>('data2');
      expect(state1, isNot(equals(state2)));
    });

    test('SuccessState supports complex data types', () {
      final data = {'key': 'value', 'count': 10};
      final state = SuccessState<Map<String, dynamic>>(data);
      expect(state.data, data);
      expect(state.data['key'], 'value');
      expect(state.data['count'], 10);
    });

    test('Different state types are not equal', () {
      const initial = InitialState();
      const loading = LoadingState();
      const error = ErrorState('error');
      const success = SuccessState<String>('data');

      expect(initial, isNot(equals(loading)));
      expect(initial, isNot(equals(error)));
      expect(initial, isNot(equals(success)));
      expect(loading, isNot(equals(error)));
      expect(loading, isNot(equals(success)));
      expect(error, isNot(equals(success)));
    });
  });

  group('AsyncResult', () {
    test('AsyncResult with no data or error is in initial state', () {
      const result = AsyncResult<String>();
      expect(result.data, isNull);
      expect(result.error, isNull);
      expect(result.isLoading, false);
      expect(result.hasData, false);
      expect(result.hasError, false);
    });

    test('AsyncResult with data has data', () {
      const result = AsyncResult<String>(data: 'test');
      expect(result.data, 'test');
      expect(result.error, isNull);
      expect(result.isLoading, false);
      expect(result.hasData, true);
      expect(result.hasError, false);
    });

    test('AsyncResult with error has error', () {
      const result = AsyncResult<String>(error: 'Failed');
      expect(result.data, isNull);
      expect(result.error, 'Failed');
      expect(result.isLoading, false);
      expect(result.hasData, false);
      expect(result.hasError, true);
    });

    test('AsyncResult with loading flag', () {
      const result = AsyncResult<String>(isLoading: true);
      expect(result.data, isNull);
      expect(result.error, isNull);
      expect(result.isLoading, true);
      expect(result.hasData, false);
      expect(result.hasError, false);
    });

    test('AsyncResult with data and loading', () {
      const result = AsyncResult<String>(data: 'test', isLoading: true);
      expect(result.data, 'test');
      expect(result.isLoading, true);
      expect(result.hasData, true);
    });

    test('AsyncResult with both data and error prioritizes error', () {
      const result = AsyncResult<String>(data: 'test', error: 'Failed');
      expect(result.data, 'test');
      expect(result.error, 'Failed');
      expect(result.hasData, false); // hasData is false when there's an error
      expect(result.hasError, true);
    });

    test('AsyncResult instances with same values are equal', () {
      const result1 = AsyncResult<int>(data: 42);
      const result2 = AsyncResult<int>(data: 42);
      expect(result1, equals(result2));
    });

    test('AsyncResult instances with different values are not equal', () {
      const result1 = AsyncResult<int>(data: 42);
      const result2 = AsyncResult<int>(data: 43);
      expect(result1, isNot(equals(result2)));
    });

    test('AsyncResult supports complex data types', () {
      final data = ['item1', 'item2', 'item3'];
      final result = AsyncResult<List<String>>(data: data);
      expect(result.data, data);
      expect(result.data?.length, 3);
      expect(result.hasData, true);
    });

    test('AsyncResult props include all fields', () {
      const result = AsyncResult<String>(
        data: 'test',
        error: 'error',
        isLoading: true,
      );
      expect(result.props, ['test', 'error', true]);
    });
  });

  group('AsyncState enum', () {
    test('AsyncState has all expected values', () {
      expect(AsyncState.values, [
        AsyncState.initial,
        AsyncState.loading,
        AsyncState.success,
        AsyncState.error,
      ]);
    });

    test('AsyncState values are distinct', () {
      expect(AsyncState.initial, isNot(equals(AsyncState.loading)));
      expect(AsyncState.initial, isNot(equals(AsyncState.success)));
      expect(AsyncState.initial, isNot(equals(AsyncState.error)));
      expect(AsyncState.loading, isNot(equals(AsyncState.success)));
      expect(AsyncState.loading, isNot(equals(AsyncState.error)));
      expect(AsyncState.success, isNot(equals(AsyncState.error)));
    });
  });

  group('State Transitions', () {
    test('Typical state flow: initial -> loading -> success', () {
      const states = [
        InitialState(),
        LoadingState(message: 'Fetching...'),
        SuccessState<String>('data'),
      ];

      expect(states[0], isA<InitialState>());
      expect(states[1], isA<LoadingState>());
      expect(states[2], isA<SuccessState<String>>());
    });

    test('Error state flow: initial -> loading -> error', () {
      const states = [
        InitialState(),
        LoadingState(message: 'Fetching...'),
        ErrorState('Network error'),
      ];

      expect(states[0], isA<InitialState>());
      expect(states[1], isA<LoadingState>());
      expect(states[2], isA<ErrorState>());
    });

    test('Retry flow: error -> loading -> success', () {
      const states = [
        ErrorState('Failed'),
        LoadingState(message: 'Retrying...'),
        SuccessState<int>(42),
      ];

      expect(states[0], isA<ErrorState>());
      expect(states[1], isA<LoadingState>());
      expect(states[2], isA<SuccessState<int>>());
    });
  });
}
