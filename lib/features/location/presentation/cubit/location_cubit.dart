import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/platform/adhan_scheduler_service.dart';
import 'package:adhan_and_prayer/features/location/data/repositories/location_repository_impl.dart';
import 'package:adhan_and_prayer/features/location/domain/entities/location_entities.dart';

sealed class LocationState {
  const LocationState();
}

class LocationInitialState extends LocationState {}

class LocationLoadingState extends LocationState {}

class LocationDataState extends LocationState {
  final List<Country> countries;
  final Country? selectedCountry;
  final List<City> cities;
  final City? selectedCity;
  final String searchQuery;

  const LocationDataState({
    required this.countries,
    this.selectedCountry,
    required this.cities,
    this.selectedCity,
    this.searchQuery = '',
  });

  LocationDataState copyWith({
    List<Country>? countries,
    Country? selectedCountry,
    List<City>? cities,
    City? selectedCity,
    String? searchQuery,
  }) {
    return LocationDataState(
      countries: countries ?? this.countries,
      selectedCountry: selectedCountry ?? this.selectedCountry,
      cities: cities ?? this.cities,
      selectedCity: selectedCity ?? this.selectedCity,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class LocationSavedState extends LocationState {
  final Country country;
  final City city;
  const LocationSavedState(this.country, this.city);
}

class LocationErrorState extends LocationState {
  final String message;
  const LocationErrorState(this.message);
}

class LocationCubit extends Cubit<LocationState> {
  final LocationRepository locationRepo;
  final AdhanSchedulerService schedulerService;

  LocationCubit({
    required this.locationRepo,
    required this.schedulerService,
  }) : super(LocationInitialState());

  Future<void> initialize() async {
    emit(LocationLoadingState());
    try {
      final countries = await locationRepo.getCountries();
      final currentCountry = await locationRepo.getSelectedCountry();
      final currentCity = await locationRepo.getSelectedCity();

      List<City> cities = [];
      if (currentCountry != null) {
        cities = await locationRepo.getCitiesForCountry(currentCountry.code);
      }

      emit(
        LocationDataState(
          countries: countries,
          selectedCountry: currentCountry,
          cities: cities,
          selectedCity: currentCity,
        ),
      );
    } catch (e) {
      emit(LocationErrorState(e.toString()));
    }
  }

  Future<void> selectCountry(Country country) async {
    final currentState = state;
    if (currentState is! LocationDataState) return;

    final cities = await locationRepo.getCitiesForCountry(country.code);
    emit(
      currentState.copyWith(
        selectedCountry: country,
        cities: cities,
        selectedCity: null,
        searchQuery: '',
      ),
    );
  }

  Future<void> searchCities(String query) async {
    final currentState = state;
    if (currentState is! LocationDataState) return;

    final results = await locationRepo.searchCities(
      query,
      countryCode: currentState.selectedCountry?.code,
    );
    emit(currentState.copyWith(cities: results, searchQuery: query));
  }

  Future<bool> saveSelection(City city) async {
    final currentState = state;
    if (currentState is! LocationDataState || currentState.selectedCountry == null) {
      return false;
    }

    final country = currentState.selectedCountry!;
    final result = await locationRepo.saveLocation(country, city);

    if (result is Success) {
      // Coordinated Transaction: Cancel old location schedules
      await schedulerService.cancelAll();
      emit(LocationSavedState(country, city));
      return true;
    } else {
      emit(LocationErrorState((result as Failure).message));
      return false;
    }
  }
}
