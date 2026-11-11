import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adhan_and_prayer/core/storage/local_storage.dart';

class OnboardingCubit extends Cubit<bool> {
  final LocalStorage _storage;
  static const String _keyOnboardingComplete = 'onboarding_complete_v1';

  OnboardingCubit(this._storage) : super(_storage.getBool(_keyOnboardingComplete) ?? false);

  bool isOnboardingComplete() {
    return state;
  }

  Future<void> completeOnboarding() async {
    await _storage.setBool(_keyOnboardingComplete, true);
    emit(true);
  }
}
