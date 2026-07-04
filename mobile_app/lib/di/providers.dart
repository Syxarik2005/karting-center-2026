import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../data/datasources/auth_remote_datasource.dart';
import '../data/datasources/bookings_remote_datasource.dart';
import '../data/datasources/slots_remote_datasource.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/bookings_repository.dart';
import '../data/repositories/slots_repository.dart';

// ── Datasources ──

final authDatasourceProvider = Provider<AuthRemoteDatasource>(
  (ref) => AuthRemoteDatasource(DioClient.instance),
);

final slotsDatasourceProvider = Provider<SlotsRemoteDatasource>(
  (ref) => SlotsRemoteDatasource(DioClient.instance),
);

final bookingsDatasourceProvider = Provider<BookingsRemoteDatasource>(
  (ref) => BookingsRemoteDatasource(DioClient.instance),
);

// ── Repositories ──

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(authDatasourceProvider)),
);

final slotsRepositoryProvider = Provider<SlotsRepository>(
  (ref) => SlotsRepository(ref.read(slotsDatasourceProvider)),
);

final bookingsRepositoryProvider = Provider<BookingsRepository>(
  (ref) => BookingsRepository(ref.read(bookingsDatasourceProvider)),
);
