import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adhan_and_prayer/core/localization/app_localizations.dart';
import 'package:adhan_and_prayer/features/location/domain/entities/location_entities.dart';
import 'package:adhan_and_prayer/features/location/presentation/cubit/location_cubit.dart';

class LocationSelectionScreen extends StatefulWidget {
  final bool isOnboarding;

  const LocationSelectionScreen({super.key, this.isOnboarding = false});

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<LocationCubit>().initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = loc.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('location')),
      ),
      body: BlocConsumer<LocationCubit, LocationState>(
        listener: (context, state) {
          if (state is LocationSavedState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.translate('location_saved'))),
            );
            if (!widget.isOnboarding) {
              Navigator.of(context).pop(true);
            }
          } else if (state is LocationErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is LocationLoadingState) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is LocationDataState) {
            return Column(
              children: [
                // Country Dropdown Selector
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<Country>(
                    initialValue: state.selectedCountry,
                    decoration: InputDecoration(
                      labelText: loc.translate('country'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.public),
                    ),
                    items: state.countries.map((country) {
                      return DropdownMenuItem<Country>(
                        value: country,
                        child: Text(country.getLocalizedName(lang)),
                      );
                    }).toList(),
                    onChanged: (country) {
                      if (country != null) {
                        _searchController.clear();
                        context.read<LocationCubit>().selectCountry(country);
                      }
                    },
                  ),
                ),

                // City Search Bar
                if (state.selectedCountry != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: loc.translate('search_city'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  context.read<LocationCubit>().searchCities('');
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        context.read<LocationCubit>().searchCities(val);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // City Results List
                Expanded(
                  child: state.selectedCountry == null
                      ? Center(
                          child: Text(
                            loc.translate('select_country'),
                            style: theme.textTheme.bodyLarge,
                          ),
                        )
                      : state.cities.isEmpty
                          ? Center(
                              child: Text(
                                loc.translate('no_cities_found'),
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                          : ListView.separated(
                              itemCount: state.cities.length,
                              separatorBuilder: (_, unused) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final city = state.cities[index];
                                final isSelected = state.selectedCity?.id == city.id;

                                return ListTile(
                                  leading: Icon(
                                    Icons.location_city,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : Colors.grey,
                                  ),
                                  title: Text(
                                    city.getLocalizedName(lang),
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${city.latitude.toStringAsFixed(2)}°, ${city.longitude.toStringAsFixed(2)}°  •  ${city.timezone}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  trailing: isSelected
                                      ? Icon(Icons.check_circle,
                                          color: theme.colorScheme.primary)
                                      : null,
                                  onTap: () {
                                    context.read<LocationCubit>().saveSelection(city);
                                  },
                                );
                              },
                            ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
