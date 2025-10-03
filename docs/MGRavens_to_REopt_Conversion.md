# MG-Ravens to REopt Input Conversion

## Overview

The `mgravens.jl` file contains functions that convert MG-Ravens (Microgrid Resilience Analysis and Visualization for Energy Networks) JSON input files into REopt-compatible JSON inputs. This conversion enables the use of REopt's optimization capabilities with MG-Ravens data structures and schema.

## Main Function: `convert_mgravens_inputs_to_reopt_inputs`

### Purpose
Transforms a MG-Ravens data dictionary into a REopt inputs dictionary by:
1. Loading default REopt values optimized for utility-scale microgrids
2. Extracting and converting MG-Ravens specific inputs
3. Building REopt-compatible data structures
4. Handling existing assets and technology options

### Input Format
- **Input**: MG-Ravens JSON data structure (loaded as Julia Dict) - see [MG-Ravens Input Structure](#mg-ravens-input-structure) below
- **Output**: REopt inputs Dictionary for use with `run_reopt()` function

## MG-Ravens Input Structure

The MG-Ravens input JSON file that gets converted contains a hierarchical structure representing the power system, economic data, and optimization scenarios. The main sections include:

### Top-Level Structure
```json
{
  "AlgorithmProperties": {                              // INPUT: Read for analysis settings
    "DesignAlgorithmProperties": { ... }
  },
  "ProposedAssetOption": {                             // INPUT: Read for technology definitions
    "ProposedEnergyProducerOption": { ... }
  },
  "ProposedSiteLocation": {                            // INPUT: Read for site/geographic data
    "<site_name>": { ... }
  },
  "Group": {                                           // INPUT/OUTPUT: Read for organization, written for results
    "LoadGroup": { ... },                              // INPUT: Read for load groupings
    "SubGeographicalRegion": { ... },                  // INPUT: Read for regional data
    "ConnectivityNodeContainer": { ... },              // INPUT: Read for microgrid definitions
    "ProposedAssetSet": {                              // OUTPUT: Created with optimization results
      "BusinessAsUsual": { ... },
      "Optimal": { ... }
    }
  },
  "PowerSystemResource": {                             // INPUT: Read for equipment definitions
    "Equipment": {
      "ConductingEquipment": {
        "EnergyConnection": {
          "EnergyConsumer": { ... },                    // INPUT: Read for load data
          "RegulatingCondEq": {
            "PowerElectronicsConnection": { ... }       // INPUT: Read for existing assets
          }
        }
      }
    }
  },
  "BasicIntervalSchedule": {                           // INPUT: Read for time series data
    "<profile_name>": { ... }
  },
  "EconomicProperty": {                                // INPUT: Read for financial parameters
    "<econ_name>": { ... }
  },
  "EnergyPrices": {                                    // INPUT: Read for electricity pricing
    "LocationalMarginalPrices": { ... },
    "CapacityPrices": { ... },
    "CoincidentPeakPrices": { ... }
  },
  "Curve": {                                           // INPUT/OUTPUT: Read for generation profiles, written for results
    "<existing_profile_name>": { ... },               // INPUT: Read for PV generation profiles
    "PVProfile_REOPT": { ... }                         // OUTPUT: Created with REopt PV dispatch results
  },
  "Document": {                                        // INPUT: Read for analysis scenarios
    "Outage": {
      "<outage_name>": { ... }
    }
  },
  "Message": [                                         // OUTPUT: Created with warnings/errors from REopt
    { 
      "Ravens.cimObjectType": "Warning",
      "Message.message": "...",
      "Message.Application": "Application::'REopt'"
    },
    {
      "Ravens.cimObjectType": "Error", 
      "Message.message": "...",
      "Message.Application": "Application::'REopt'"
    }
  ],
  "EstimatedCost": {                                   // OUTPUT: Created with lifecycle cost results
    "BusinessAsUsual": { ... },
    "Optimal": { ... }
  },
  "ProposedAsset": {                                   // OUTPUT: Created with optimal technology results
    "REopt_PV": { ... },
    "REopt_ESS": { ... }
  }
}
```

### AlgorithmProperties
Contains optimization algorithm settings:
```json
"AlgorithmProperties": {
  "DesignAlgorithmProperties": {
    "<algorithm_name>": {
      "AlgorithmProperties.analysisPeriod": "P25Y"  // ISO 8601 duration
    }
  }
}
```

### ProposedAssetOption
Defines the technology options to evaluate:
```json
"ProposedAssetOption": {
  "ProposedEnergyProducerOption": {
    "<tech_name_1>": {
      "Ravens.cimObjectType": "ProposedPhotoVoltaicUnitOption",
      "ProposedAssetOption.ProposedLocations": ["ProposedSiteLocation::'<site_name>'"],
      "ProposedEnergyProducerOption.powerCapacityMin": {...},
      "ProposedEnergyProducerOption.powerCapacityMax": {...},
      "ProposedEnergyProducerOption.variablePrice": {...},
      "ProposedPhotoVoltaicUnitOption.GenerationProfile": "Curve::'<profile_name>'"
    },
    "<tech_name_2>": {
      "Ravens.cimObjectType": "ProposedBatteryUnitOption",
      "ProposedBatteryUnitOption.energyCapacityMin": {...},
      "ProposedBatteryUnitOption.energyCapacityMax": {...},
      "ProposedBatteryUnitOption.chargeEfficiency": 95.0,
      "ProposedBatteryUnitOption.dischargeEfficiency": 95.0
    }
  }
}
```

### ProposedSiteLocation
Geographic and site-specific information:
```json
"ProposedSiteLocation": {
  "<site_name>": {
    "ProposedSiteLocation.availableArea": 50000.0,  // square meters
    "Location.PositionPoints": [{
      "PositionPoint.xPosition": "-105.1234",  // longitude
      "PositionPoint.yPosition": "39.5678"     // latitude
    }],
    "ProposedSiteLocation.LoadGroups": ["LoadGroup::'<group_name>'"],
    "ProposedSiteLocation.Region": "SubGeographicalRegion::'<region_name>'"
  }
}
```

### Group
Organizational structures for loads, regions, and microgrids:
```json
"Group": {
  "LoadGroup": {
    "<group_name>": {
      "LoadGroup.EnergyConsumers": ["EnergyConsumer::'<consumer_name>'"]
    }
  },
  "SubGeographicalRegion": {
    "<region_name>": {
      "SubGeographicalRegion.EconomicProperty": "EconomicProperty::'<econ_name>'",
      "SubGeographicalRegion.LocationalMarginalPrices": "LocationalMarginalPrices::'<lmp_name>'",
      "SubGeographicalRegion.CapacityPrices": "CapacityPrices::'<capacity_name>'"
    }
  },
  "ConnectivityNodeContainer": {
    "Microgrid.1": {
      "EquipmentContainer.Equipments": [
        "EnergyConsumer::'<critical_consumer>'",
        "PhotoVoltaicUnit::'<existing_pv>'",
        "BatteryUnit::'<existing_battery>'"
      ]
    }
  }
}
```

### PowerSystemResource
Detailed equipment and energy consumer definitions:
```json
"PowerSystemResource": {
  "Equipment": {
    "ConductingEquipment": {
      "EnergyConnection": {
        "EnergyConsumer": {
          "<consumer_name>": {
            "EnergyConsumer.LoadProfile": "BasicIntervalSchedule::'<profile_name>'",
            "EnergyConsumer.p": 1000.0  // or EnergyConsumer.EnergyConsumerPhase array
          }
        },
        "RegulatingCondEq": {
          "PowerElectronicsConnection": {
            "<asset_name>": {
              "PowerElectronicsConnection.PowerElectronicsUnit": {
                "Ravens.cimObjectType": "PhotoVoltaicUnit|BatteryUnit",
                "PowerElectronicsUnit.maxP": {...},
                "BatteryUnit.ratedE": {...}  // for batteries only
              }
            }
          }
        }
      }
    }
  }
}
```

### BasicIntervalSchedule
Time series data for loads and generation:
```json
"BasicIntervalSchedule": {
  "<profile_name>": {
    "EnergyConsumerSchedule.timeStep": 3600,  // seconds (3600 or 900)
    "EnergyConsumerSchedule.startDate": "01-01-2024",
    "EnergyConsumerSchedule.RegularTimePoints": [
      {"RegularTimePoint.value1": 250.5},
      {"RegularTimePoint.value1": 275.2},
      // ... hourly or 15-minute values
    ],
    "BasicIntervalSchedule.value1Unit": "UnitSymbol.W",  // optional
    "BasicIntervalSchedule.value1Multiplier": "UnitMultiplier.k"  // optional
  }
}
```

### EconomicProperty
Financial parameters:
```json
"EconomicProperty": {
  "<econ_name>": {
    "EconomicProperty.discountRate": 5.5,      // percent
    "EconomicProperty.inflationRate": 2.5,     // percent  
    "EconomicProperty.taxRate": 25.0           // percent
  }
}
```

### EnergyPrices
Electricity pricing structures:
```json
"EnergyPrices": {
  "LocationalMarginalPrices": {
    "<lmp_name>": {
      "LocationalMarginalPrices.LMPCurve": {
        "PriceCurve.CurveDatas": [
          {"CurveData.y1value": 0.045},  // $/kWh
          {"CurveData.y1value": 0.052},
          // ... hourly values matching load profile length
        ]
      }
    }
  },
  "CapacityPrices": {
    "<capacity_name>": {
      "CapacityPrices.CapacityPriceCurve": {
        "PriceCurve.CurveDatas": [
          {"CurveData.y1value": 15.50},  // $/kW-month, 12 monthly values
          {"CurveData.y1value": 16.25},
          // ... 12 monthly values total
        ]
      }
    }
  },
  "CoincidentPeakPrices": {  // optional
    "<coincident_name>": {
      "CoincidentPeakPrices.CoincidentPeakPriceCurve": {
        "PriceCurve.CurveDatas": [
          {
            "CurveData.y1value": 25.0,    // $/kW
            "CurveData.xvalue": 2500       // timestep when active
          }
        ]
      }
    }
  }
}
```

### Curve
Generation profiles for PV and other technologies:
```json
"Curve": {
  "<profile_name>": {
    "IdentifiedObject.name": "<profile_name>",
    "Ravens.cimObjectType": "Curve",
    "Curve.y1Unit": "UnitSymbol.W",  // optional
    "Curve.y1Multiplier": "UnitMultiplier.k",  // optional
    "Curve.CurveDatas": [
      {"CurveData.y1value": 0.0, "CurveData.xvalue": 0},
      {"CurveData.y1value": 0.15, "CurveData.xvalue": 1},
      // ... 8760 hourly values (normalized production factors)
    ]
  }
}
```

### Document
Outage scenarios and analysis parameters:
```json
"Document": {
  "Outage": {
    "<outage_name>": {
      "OutageScenario.anticipatedDuration": "P24H",  // ISO 8601 duration
      "OutageScenario.loadFractionCritical": 75.0,   // percent
      "OutageScenario.anticipatedStartDay": "15-06-2024",  // optional
      "OutageScenario.anticipatedStartHour": 14        // optional hour 0-23
    }
  }
}
```

### Value Objects
Many fields use structured value objects with units:
```json
{
  "value": 1000.0,
  "unit": "UnitSymbol.W",           // W, Wh, USD, etc.
  "multiplier": "UnitMultiplier.k"  // k=kilo, M=mega, etc.
}
```

## Key Conversion Components

### 1. Analysis Period Setup
- Extracts analysis period from `AlgorithmProperties.DesignAlgorithmProperties`
- Converts ISO 8601 duration format (e.g., "P25Y") to years
- Maps to REopt's `Financial.analysis_years`

### 2. Site Location Data
**Source**: `ProposedSiteLocation`
- **Latitude/Longitude**: Extracted from `Location.PositionPoints`
- **Land Area**: Converted from square meters to acres
- **Regional Information**: Used for economic properties and energy pricing

### 3. Load Profile Processing
**Source**: Multiple EnergyConsumers and LoadGroups

#### Load Aggregation Process:
1. **Identifies Energy Consumers**: From LoadGroups or all available EnergyConsumers
2. **Extracts Load Profiles**: From `BasicIntervalSchedule.RegularTimePoints`
3. **Handles Time Resolution**: Supports 15-minute (900s) and hourly (3600s) intervals
4. **Scales to Annual**: Repeats partial data to create full year profiles
5. **Aggregates Total Load**: Sums all consumer loads into `ElectricLoad.loads_kw`

#### Critical Load Handling:
- Identifies microgrid-specific consumers from `ConnectivityNodeContainer.Microgrid`
- Creates separate `critical_loads_kw` profile for outage analysis

#### Load Profile Features:
- **Unit Handling**: Automatically converts Watts to kW
- **Normalized Profiles**: Applies power allocation factors when load profiles lack units
- **Multi-Consumer Support**: Aggregates multiple energy consumers
- **Time Series Validation**: Ensures consistent timesteps across all profiles

### 4. Financial Parameters
**Source**: `EconomicProperty` within SubGeographicalRegion

Maps MG-Ravens financial inputs to REopt equivalents:
- `discountRate` → `offtaker_discount_rate_fraction`
- `inflationRate` → `om_cost_escalation_rate_fraction`  
- `taxRate` → `offtaker_tax_rate_fraction`

Automatically converts percentages to decimal fractions.

### 5. Energy Pricing
#### Locational Marginal Prices (LMP)
**Source**: `EnergyPrices.LocationalMarginalPrices`
- Extracts hourly energy prices from `PriceCurve.CurveDatas`
- Maps to REopt's `tou_energy_rates_per_kwh`
- Validates time series length matches load profiles

#### Capacity Prices
**Source**: `EnergyPrices.CapacityPrices`
- Extracts monthly demand charges
- Maps to REopt's `monthly_demand_rates`
- Requires exactly 12 monthly values

#### Coincident Peak Prices (Optional)
**Source**: `EnergyPrices.CoincidentPeakPrices`
- Extracts time-specific peak demand charges
- Maps to REopt's `coincident_peak_load_charge_per_kw` and `coincident_peak_load_active_time_steps`

### 6. Outage Analysis
**Source**: `Document.Outage`

Processes outage scenarios:
- **Duration**: Converts ISO 8601 format to hours
- **Critical Load Fraction**: Percentage of total load considered critical
- **Start Times**: Optional outage start times (defaults to seasonal peaks)
- **Aggregation**: Averages multiple outage scenarios for REopt compatibility

### 7. Technology Options

#### Solar PV (`ProposedPhotoVoltaicUnitOption`)
**Capacity Constraints**:
- `powerCapacityFixed` → sets both min and max kW
- `powerCapacityMin/Max` → sets capacity bounds
- `variablePrice` → `installed_cost_per_kw`
- `operationsAndMaintenanceRateFixed` → `om_cost_per_kw`

**Production Profiles**:
- Custom profiles from `GenerationProfile` → `production_factor_series`
- Falls back to PVWatts API if no profile provided

#### Battery Storage (`ProposedBatteryUnitOption`)
**Capacity Constraints**:
- `energyCapacityFixed/Min/Max` → energy capacity bounds (kWh)
- `powerCapacityFixed/Min/Max` → power capacity bounds (kW)

**Performance Parameters**:
- `chargeEfficiency` → `rectifier_efficiency_fraction`
- `dischargeEfficiency` → `inverter_efficiency_fraction`
- `stateOfChargeMin` → `soc_min_fraction`

**Cost Parameters**:
- `variablePrice` → `installed_cost_per_kw`
- `variablePriceEnergy` → `installed_cost_per_kwh`

### 8. Existing Assets Handling

#### Existing PV Systems
- **Grid-tied PV**: Generation subtracted from load profile
- **Microgrid PV**: Included as `existing_kw` capacity
- **Production Profiles**: Uses largest existing PV profile for optimization

#### Existing Battery Systems
- **Microgrid Batteries**: Modeled as zero-cost initial capacity
- **Cost Adjustment**: Uses negative `installed_cost_constant` to account for existing capacity
- **Minimum Constraints**: Sets minimum capacity equal to existing capacity

## Helper Functions

### `build_timeseries_array(list_of_dict, y_value_name, timestep_sec)`
**Purpose**: Creates annual time series from partial data
- **Input Validation**: Ensures valid timestep (900s or 3600s)
- **Scaling Logic**: Repeats data to fill 8760 hours (or 35,040 15-minute intervals)
- **Truncation**: Removes excess data points to maintain exact annual length

### `get_value_in_kw(object)`
**Purpose**: Standardizes power/energy values to kW/kWh
- **Unit Detection**: Handles both unit objects and raw values
- **Multiplier Handling**: Converts based on `UnitMultiplier.k` (kilo) designation
- **Default Conversion**: Assumes Watts and converts to kW (÷1000)

### `cost_template(value)`
**Purpose**: Creates standardized cost dictionary for MG-Ravens output
- **Currency**: Always USD
- **Format**: Consistent structure for all cost values

## Output Processing

### `update_mgravens_with_reopt_results!`
**Purpose**: Updates MG-Ravens structure with REopt optimization results

#### Result Categories:
1. **Messages**: Warnings and errors from optimization
2. **Asset Sets**: Business-as-usual vs. optimal scenarios
3. **Cost Estimates**: Lifecycle costs by scenario and component
4. **Technology Results**: Optimal capacities and dispatch profiles

#### Financial Outputs:
- **Lifecycle Costs**: Capital, energy, capacity, and total costs
- **Net Present Value**: Economic benefit of optimal vs. BAU
- **Scenario Comparison**: Side-by-side cost analysis

## Data Flow Summary

```
MG-Ravens Input JSON
(Complex hierarchical structure with power system data)
         ↓
1. Load Default REopt Values
         ↓
2. Extract Site & Location Data
         ↓
3. Process Load Profiles
         ↓
4. Extract Financial Parameters
         ↓
5. Process Energy Pricing
         ↓
6. Configure Outage Scenarios
         ↓
7. Process Technology Options
         ↓
8. Handle Existing Assets
         ↓
9. Validate & Clean Inputs
         ↓
REopt-Compatible JSON
         ↓
REopt Optimization
         ↓
Results Integration Back to MG-Ravens
```

## Key Assumptions & Limitations

### Assumptions:
- All proposed energy producers share the same site location
- Load profile timesteps are consistent across all energy consumers
- Energy prices apply uniformly across all loads
- Analysis focuses on electrical systems (no thermal modeling)

### Limitations:
- Single outage duration per analysis (cannot model varying durations)
- Limited to PV and battery storage technologies
- Cannot model economy of scale with existing battery systems
- Requires monthly capacity prices (exactly 12 values)

## Default Values

The conversion relies on `mgravens_fields_defaults.json` which provides:
- **Site**: Default large land area (100M acres)
- **PV**: Default REopt costs which vary based on scale from the ATB
- **Battery**: Default large commercial-scale cost curve from the ATB
- **Financial**: 25-year analysis period
- **Settings**: Hourly time resolution default

These defaults are specifically tailored for utility-scale microgrid applications, differing from REopt's standard commercial & industrial defaults.

## Error Handling

The conversion includes comprehensive error checking for:
- **Timestep Validation**: Ensures 900s or 3600s intervals
- **Data Consistency**: Validates matching time series lengths
- **Required Fields**: Checks for essential MG-Ravens inputs
- **Unit Conversion**: Handles missing or inconsistent units
- **Technology Compatibility**: Ensures technology options are properly defined

This robust error handling ensures reliable conversion from MG-Ravens to REopt while providing clear diagnostic information when issues arise.