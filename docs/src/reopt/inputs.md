# REopt Inputs
Inputs to `run_reopt` can be provided in one of three formats:
1. a file path (string) to a JSON file,
2. a `Dict`, or
3. using the `REoptInputs` struct

The first option is perhaps the most straightforward one. For example, the minimum requirements for a JSON scenario file would look like:
```javascript
{
    "Site": {
        "longitude": -118.1164613,
        "latitude": 34.5794343
    },
    "ElectricLoad": {
        "doe_reference_name": "MidriseApartment",
        "annual_kwh": 1000000.0,
        "city": "Boulder"
    },
    "ElectricTariff": {
        "urdb_label": "5ed6c1a15457a3367add15ae"
    }
}
```
The order of the keys do not matter. Note that this scenario does not include any energy generation technologies and therefore the results can be used as a baseline for comparison to scenarios that result in cost-optimal generation technologies.

To add PV to the analysis simply add a PV key with an empty dictionary (to use default values):
```javascript
{
    "Site": {
        "longitude": -118.1164613,
        "latitude": 34.5794343
    },
    "ElectricLoad": {
        "doe_reference_name": "MidriseApartment",
        "annual_kwh": 1000000.0,
        "city": "Boulder"
    },
    "ElectricTariff": {
        "urdb_label": "5ed6c1a15457a3367add15ae"
    },
    "PV": {}
}
```
This scenario will consider the option to purchase a solar PV system to reduce energy costs, and if solar PV can reduce the energy costs then REopt Lite will provide the optimal PV capacity (assuming perfect foresight!). To use other than default values for `PV` see the [PV struct definition](https://github.com/NREL/REoptLite/blob/master/src/core/pv.jl).  For example, the site under consideration might have some existing PV capacity to account for, which can be done by setting the `existing_kw` key to the appropriate value.

## Scenario
The `Scenario` struct captures all of the objects that can be included in a scenario.json:
```@docs
Scenario
```

## REoptInputs
```@docs
REoptLite.REoptInputs
```

## ElectricLoad
```@docs
REoptLite.ElectricLoad
```

## Financial values
```@docs
REoptLite.Financial
```

## ElectricUtility
```@docs
REoptLite.ElectricUtility
```

## Generator
```@docs
REoptLite.Generator
```

## ElectricTariff
```@docs
REoptLite.ElectricTariff
```

## Settings
```@docs
REoptLite.Settings
```
