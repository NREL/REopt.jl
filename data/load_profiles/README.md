# DoE Commercial Reference Building load profiles
This folder contains electric, heating, and cooling loads from the DoE Commercial Reference Buildings.

## electric
- units: kWh

## domestic_hot_water
- units: MMBTU

## space_heating
- units: MMBTU

## Copied from API, TODO refine:
This folder contains load data generated from EnergyPlus building models (1989 code) of the DOE commercial reference buildings for cities which represent different ASHRAE climate zones (256 files per folder). Each of the four folders (Electric, Cooling, SpaceHeating, and DHW) contains normalized hourly profiles (8760 hours) representing the fraction of the annual energy that is the load for each hour. 

The space heating and domestic hot water (DHW) normalized profiles are slightly different, as described below. The other files in the folder contain annual energy values for DHW, SpaceHeating, combined DHW+SpaceHeating, and cooling (electric consumption from an electric chiller, described more below). The annual_heating_stats.csv contains additional data for heating load for future use.

Folders:
- electric
    - This is the total facility electric load
    - The normalized profiles are the fraction of `ElectricLoad.annual_kwh` for each hour
- cooling
    - This is a subset of the total facility electric load that is consumed for cooling by the existing electric chiller plant
    - The normalized profiles are the fraction of `CoolingLoad.annual_tonhour`
- space_heating
    - This is a subset of the total facility heating gas load that is consumed for space heating
    - The normalized profiles are the fraction of the annual facility gas load for space heating `SpaceHeatingLoad.annual_mmbtu`
- domestic_hot_water
    - This is a subset of the total facility heating gas load  that is consumed for domestic hot water
    - The normalized profiles are the fraction of the annual facility gas load for domestic hot water `DomesticHotWaterLoad.annual_mmbtu`