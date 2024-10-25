# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`ElectricLoad` is a required REopt input with the following keys and default values:
```julia
    loads_kw::Array{<:Real,1} = Real[],
    normalize_and_scale_load_profile_input::Bool = false,  # Takes loads_kw and normalizes and scales it to annual or monthly energy
    path_to_csv::String = "", # for csv containing loads_kw
    doe_reference_name::String = "",
    blended_doe_reference_names::Array{String, 1} = String[],
    blended_doe_reference_percents::Array{<:Real,1} = Real[], # Values should be between 0-1 and sum to 1.0
    year::Int = doe_reference_name ≠ "" || blended_doe_reference_names ≠ String[] ? 2017 : 2022, # used in ElectricTariff to align rate schedule with weekdays/weekends. DOE CRB profiles must use 2017. If providing load data, specify year of data.
    city::String = "",
    annual_kwh::Union{Real, Nothing} = nothing,
    monthly_totals_kwh::Array{<:Real,1} = Real[],
    critical_loads_kw::Union{Nothing, Array{Real,1}} = nothing,
    loads_kw_is_net::Bool = true,
    critical_loads_kw_is_net::Bool = false,
    critical_load_fraction::Real = off_grid_flag ? 1.0 : 0.5, # if off grid must be 1.0, else 0.5
    operating_reserve_required_fraction::Real = off_grid_flag ? 0.1 : 0.0, # if off grid, 10%, else must be 0%. Applied to each time_step as a % of electric load.
    min_load_met_annual_fraction::Real = off_grid_flag ? 0.99999 : 1.0 # if off grid, 99.999%, else must be 100%. Applied to each time_step as a % of electric load.
```

!!! note "Required inputs"
    Must provide either `loads_kw` or `path_to_csv` or [`doe_reference_name` and `city`] or `doe_reference_name` or [`blended_doe_reference_names` and `blended_doe_reference_percents`]. 

    When only `doe_reference_name` is provided the `Site.latitude` and `Site.longitude` are used to look up the ASHRAE climate zone, which determines the appropriate DoE Commercial Reference Building profile.

    When using the [`doe_reference_name` and `city`] option, choose `city` from one of the cities used to represent the ASHRAE climate zones:
    - Albuquerque
    - Atlanta
    - Baltimore
    - Boulder
    - Chicago
    - Duluth
    - Fairbanks
    - Helena
    - Houston
    - LosAngeles
    - LasVegas
    - Miami
    - Minneapolis
    - Phoenix
    - SanFrancisco
    - Seattle
    and `doe_reference_name` from:
    - FastFoodRest
    - FullServiceRest
    - Hospital
    - LargeHotel
    - LargeOffice
    - MediumOffice
    - MidriseApartment
    - Outpatient
    - PrimarySchool
    - RetailStore
    - SecondarySchool
    - SmallHotel
    - SmallOffice
    - StripMall
    - Supermarket
    - Warehouse
    - FlatLoad # constant load year-round
    - FlatLoad_24_5 # constant load all hours of the weekdays
    - FlatLoad_16_7 # two 8-hour shifts for all days of the year; 6-10 a.m.
    - FlatLoad_16_5 # two 8-hour shifts for the weekdays; 6-10 a.m.
    - FlatLoad_8_7 # one 8-hour shift for all days of the year; 9 a.m.-5 p.m.
    - FlatLoad_8_5 # one 8-hour shift for the weekdays; 9 a.m.-5 p.m.

    Each `city` and `doe_reference_name` combination has a default `annual_kwh`, or you can provide your
    own `annual_kwh` or `monthly_totals_kwh` and the reference profile will be scaled appropriately.


!!! note "Year" 
    The ElectricLoad `year` is used in ElectricTariff to align rate schedules with weekdays/weekends. If providing your own `loads_kw`, ensure the `year` matches the year of your data.
    If utilizing `doe_reference_name` or `blended_doe_reference_names`, the default year of 2017 is used because these load profiles start on a Sunday.
"""
mutable struct ElectricLoad  # mutable to adjust (critical_)loads_kw based off of (critical_)loads_kw_is_net
    loads_kw::Array{Real,1}
    year::Int  # used in ElectricTariff to align rate schedule with weekdays/weekends
    critical_loads_kw::Array{Real,1}
    loads_kw_is_net::Bool
    critical_loads_kw_is_net::Bool
    city::String
    operating_reserve_required_fraction::Real
    min_load_met_annual_fraction::Real
    
    function ElectricLoad(;
        off_grid_flag::Bool = false,
        loads_kw::Array{<:Real,1} = Real[],
        normalize_and_scale_load_profile_input::Bool = false,
        path_to_csv::String = "",
        doe_reference_name::String = "",
        blended_doe_reference_names::Array{String, 1} = String[],
        blended_doe_reference_percents::Array{<:Real,1} = Real[],
        year::Int = doe_reference_name ≠ "" || blended_doe_reference_names ≠ String[] ? 2017 : 2022, # used in ElectricTariff to align rate schedule with weekdays/weekends. DOE CRB profiles must use 2017. If providing load data, specify year of data.
        city::String = "",
        annual_kwh::Union{Real, Nothing} = nothing,
        monthly_totals_kwh::Array{<:Real,1} = Real[],
        critical_loads_kw::Union{Nothing, Array{Real,1}} = nothing,
        loads_kw_is_net::Bool = true,
        critical_loads_kw_is_net::Bool = false,
        critical_load_fraction::Real = off_grid_flag ? 1.0 : 0.5, # if off grid, must be 1.0, else 0.5
        latitude::Real,
        longitude::Real,
        time_steps_per_hour::Int = 1,
        operating_reserve_required_fraction::Real = off_grid_flag ? 0.1 : 0.0, # if off grid, 10%, else must be 0%
        min_load_met_annual_fraction::Real = off_grid_flag ? 0.99999 : 1.0 # if off grid, 99.999%, else must be 100%. Applied to each time_step as a % of electric load.
        )
        
        if off_grid_flag
            if !isnothing(critical_loads_kw)
                @warn "ElectricLoad critical_loads_kw will be ignored because `off_grid_flag` is true. If you wish to alter the load profile or load met, adjust the loads_kw or min_load_met_annual_fraction."
                critical_loads_kw = nothing
            end
            if critical_load_fraction != 1.0
                @warn "ElectricLoad critical_load_fraction must be 1.0 (100%) for off-grid scenarios. Any other value will be overriden when `off_grid_flag` is true. If you wish to alter the load profile or load met, adjust the loads_kw or min_load_met_annual_fraction."
                critical_load_fraction = 1.0
            end
        end

        if !(off_grid_flag)
            if !(operating_reserve_required_fraction == 0.0)
                @warn "ElectricLoad operating_reserve_required_fraction must be 0 for on-grid scenarios. Operating reserve requirements apply to off-grid scenarios only."
                operating_reserve_required_fraction = 0.0
            elseif !(min_load_met_annual_fraction == 1.0)
                @warn "ElectricLoad min_load_met_annual_fraction must be 1.0 for on-grid scenarios. This input applies to off-grid scenarios only."
                min_load_met_annual_fraction = 1.0
            end
        end

        if length(loads_kw) > 0 && !normalize_and_scale_load_profile_input

            if !(length(loads_kw) / time_steps_per_hour ≈ 8760)
                throw(@error("Provided electric load does not match the time_steps_per_hour."))
            end
        
        elseif length(loads_kw) > 0 && normalize_and_scale_load_profile_input
            if !isempty(doe_reference_name)
                @warn "loads_kw provided with normalize_and_scale_load_profile_input = true, so ignoring location and building type inputs, and only using the year and annual or monthly energy inputs with the load profile"
            end
            if isnothing(annual_kwh) && isempty(monthly_totals_kwh)
                throw(@error("Provided loads_kw with normalize_and_scale_load_profile_input=true, but no annual_kwh or monthly_totals_kwh was provided"))
            end
            # Using dummy values for all unneeded location and building type arguments for normalizing and scaling load profile input
            normalized_profile = loads_kw ./ sum(loads_kw)
            # Need year still mainly for
            loads_kw = BuiltInElectricLoad("Chicago", "LargeOffice", 41.8333, -88.0616, year, annual_kwh, monthly_totals_kwh, normalized_profile)            

        elseif !isempty(path_to_csv)
            try
                loads_kw = vec(readdlm(path_to_csv, ',', Float64, '\n'))
            catch e
                throw(@error("Unable to read in electric load profile from $path_to_csv. Please provide a valid path to a csv with no header."))
            end

            if !(length(loads_kw) / time_steps_per_hour ≈ 8760)
                throw(@error("Provided electric load does not match the time_steps_per_hour."))
            end
    
        elseif !isempty(doe_reference_name)
            # NOTE: must use year that starts on Sunday with DOE reference doe_ref_profiles
            if year != 2017
                @warn "Changing load profile year to 2017 because DOE reference profiles start on a Sunday."
            end
            year = 2017
            loads_kw = BuiltInElectricLoad(city, doe_reference_name, latitude, longitude, year, annual_kwh, monthly_totals_kwh)

        elseif length(blended_doe_reference_names) > 1 && 
            length(blended_doe_reference_names) == length(blended_doe_reference_percents)
            loads_kw = blend_and_scale_doe_profiles(BuiltInElectricLoad, latitude, longitude, year, 
                                                    blended_doe_reference_names, blended_doe_reference_percents, city, 
                                                    annual_kwh, monthly_totals_kwh)
            # TODO: Should also warn here about year 2017
        else
            throw(@error("Cannot construct ElectricLoad. You must provide either [loads_kw], [doe_reference_name, city], 
                  [doe_reference_name, latitude, longitude], 
                  or [blended_doe_reference_names, blended_doe_reference_percents] with city or latitude and longitude."))
        end

        if length(loads_kw) < 8760*time_steps_per_hour
            loads_kw = repeat(loads_kw, inner=Int(time_steps_per_hour / (length(loads_kw)/8760)))
            @warn "Repeating electric loads in each hour to match the time_steps_per_hour."
        end

        if isnothing(critical_loads_kw)
            critical_loads_kw = critical_load_fraction * loads_kw
        end

        new(
            loads_kw,
            year,
            critical_loads_kw,
            loads_kw_is_net,
            critical_loads_kw_is_net,
            city,
            operating_reserve_required_fraction,
            min_load_met_annual_fraction
        )
    end
end


function BuiltInElectricLoad(
    city::String,
    buildingtype::String,
    latitude::Real,
    longitude::Real,
    year::Int,
    annual_kwh::Union{Real, Nothing}=nothing,
    monthly_totals_kwh::Vector{<:Real}=Real[],
    normalized_profile::Union{Vector{Float64}, Vector{<:Real}}=Real[]
    )
    
    annual_loads = Dict(
        "Albuquerque" => Dict(
            "fastfoodrest" => 193235,
            "fullservicerest" => 367661,
            "hospital" => 8468546,
            "largehotel" => 2407649,
            "largeoffice" => 6303595,
            "mediumoffice" => 884408,
            "midriseapartment" => 269734,
            "outpatient" => 1678720,
            "primaryschool" => 1070908,
            "retailstore" => 505417,
            "secondaryschool" => 2588879,
            "smallhotel" => 755373,
            "smalloffice" => 87008,
            "stripmall" => 497132,
            "supermarket" => 1947654,
            "warehouse" => 228939,
            "flatload" => 500000
        ),
        "Atlanta" => Dict(
            "fastfoodrest" => 197467,
            "fullservicerest" => 353750,
            "hospital" => 9054747,
            "largehotel" => 2649819,
            "largeoffice" => 6995864,
            "mediumoffice" => 929349,
            "midriseapartment" => 285349,
            "outpatient" => 1672434,
            "primaryschool" => 1128702,
            "retailstore" => 543340,
            "secondaryschool" => 2849901,
            "smallhotel" => 795777,
            "smalloffice" => 90162,
            "stripmall" => 529719,
            "supermarket" => 2092966,
            "warehouse" => 223009,
            "flatload" => 500000
        ),
        "Baltimore" => Dict(
            "fastfoodrest" => 192831,
            "fullservicerest" => 341893,
            "hospital" => 8895223,
            "largehotel" => 2534272,
            "largeoffice" => 6836130,
            "mediumoffice" => 945425,
            "midriseapartment" => 273225,
            "outpatient" => 1623103,
            "primaryschool" => 1077312,
            "retailstore" => 510257,
            "secondaryschool" => 2698987,
            "smallhotel" => 767538,
            "smalloffice" => 86112,
            "stripmall" => 504715,
            "supermarket" => 2018760,
            "warehouse" => 229712,
            "flatload" => 500000
        ),
        "Boulder" => Dict(
            "fastfoodrest" => 189092,
            "fullservicerest" => 334005,
            "hospital" => 8281865,
            "largehotel" => 2313151,
            "largeoffice" => 6127030,
            "mediumoffice" => 884726,
            "midriseapartment" => 255428,
            "outpatient" => 1621950,
            "primaryschool" => 1018424,
            "retailstore" => 504256,
            "secondaryschool" => 2441588,
            "smallhotel" => 736174,
            "smalloffice" => 84900,
            "stripmall" => 495018,
            "supermarket" => 1956244,
            "warehouse" => 243615,
            "flatload" => 500000
        ),
        "Chicago" => Dict(
            "fastfoodrest" => 189558,
            "fullservicerest" => 333659,
            "hospital" => 8567087,
            "largehotel" => 2402021,
            "largeoffice" => 6369028,
            "mediumoffice" => 972772,
            "midriseapartment" => 265528,
            "outpatient" => 1587062,
            "primaryschool" => 1045477,
            "retailstore" => 513106,
            "secondaryschool" => 2568086,
            "smallhotel" => 759657,
            "smalloffice" => 86224,
            "stripmall" => 506886,
            "supermarket" => 2025507,
            "warehouse" => 245750,
            "flatload" => 500000
        ),
        "Duluth" => Dict(
            "fastfoodrest" => 183713,
            "fullservicerest" => 318867,
            "hospital" => 8134328,
            "largehotel" => 2231678,
            "largeoffice" => 6036003,
            "mediumoffice" => 1032533,
            "midriseapartment" => 256393,
            "outpatient" => 1534322,
            "primaryschool" => 982163,
            "retailstore" => 532503,
            "secondaryschool" => 2333466,
            "smallhotel" => 752284,
            "smalloffice" => 83759,
            "stripmall" => 500979,
            "supermarket" => 1980986,
            "warehouse" => 256575,
            "flatload" => 500000
        ),
        "Fairbanks" => Dict(
            "fastfoodrest" => 182495,
            "fullservicerest" => 314760,
            "hospital" => 7899166,
            "largehotel" => 2181664,
            "largeoffice" => 5956232,
            "mediumoffice" => 1267132,
            "midriseapartment" => 271840,
            "outpatient" => 1620270,
            "primaryschool" => 986128,
            "retailstore" => 573411,
            "secondaryschool" => 2344790,
            "smallhotel" => 831480,
            "smalloffice" => 86614,
            "stripmall" => 545421,
            "supermarket" => 2033295,
            "warehouse" => 285064,
            "flatload" => 500000
        ),
        "Helena" => Dict(
            "fastfoodrest" => 185877,
            "fullservicerest" => 325263,
            "hospital" => 8068698,
            "largehotel" => 2246239,
            "largeoffice" => 6003137,
            "mediumoffice" => 930630,
            "midriseapartment" => 252659,
            "outpatient" => 1568262,
            "primaryschool" => 994496,
            "retailstore" => 534933,
            "secondaryschool" => 2357548,
            "smallhotel" => 729797,
            "smalloffice" => 84219,
            "stripmall" => 503504,
            "supermarket" => 1969137,
            "warehouse" => 252245,
            "flatload" => 500000
        ),
        "Houston" => Dict(
            "fastfoodrest" => 210283,
            "fullservicerest" => 383987,
            "hospital" => 9634661,
            "largehotel" => 3050370,
            "largeoffice" => 7539308,
            "mediumoffice" => 972535,
            "midriseapartment" => 335063,
            "outpatient" => 1756541,
            "primaryschool" => 1258146,
            "retailstore" => 589419,
            "secondaryschool" => 3421024,
            "smallhotel" => 863952,
            "smalloffice" => 98508,
            "stripmall" => 577987,
            "supermarket" => 2225265,
            "warehouse" => 221593,
            "flatload" => 500000
        ),
        "LosAngeles" => Dict(
            "fastfoodrest" => 188857,
            "fullservicerest" => 352240,
            "hospital" => 8498389,
            "largehotel" => 2458786,
            "largeoffice" => 6642784,
            "mediumoffice" => 846742,
            "midriseapartment" => 248028,
            "outpatient" => 1565008,
            "primaryschool" => 1095263,
            "retailstore" => 486188,
            "secondaryschool" => 2584380,
            "smallhotel" => 751880,
            "smalloffice" => 86655,
            "stripmall" => 491972,
            "supermarket" => 1935886,
            "warehouse" => 182085,
            "flatload" => 500000
        ),
        "LasVegas" => Dict(
            "retailstore" => 552267,
            "largehotel" => 2751152,
            "mediumoffice" => 959668,
            "stripmall" => 546209,
            "primaryschool" => 1196111,
            "warehouse" => 235888,
            "smalloffice" => 95801,
            "supermarket" => 2001224,
            "midriseapartment" => 332312,
            "fullservicerest" => 372350,
            "outpatient" => 1782941,
            "fastfoodrest" => 208062,
            "smallhotel" => 818012,
            "largeoffice" => 6750393,
            "secondaryschool" => 3112938,
            "hospital" => 9011047,
            "flatload" => 1920398
        ),        
        "Miami" => Dict(
            "fastfoodrest" => 224494,
            "fullservicerest" => 448713,
            "hospital" => 10062043,
            "largehotel" => 3437188,
            "largeoffice" => 8002063,
            "mediumoffice" => 1021224,
            "midriseapartment" => 424956,
            "outpatient" => 1929148,
            "primaryschool" => 1426635,
            "retailstore" => 635086,
            "secondaryschool" => 4074081,
            "smallhotel" => 972090,
            "smalloffice" => 108279,
            "stripmall" => 675793,
            "supermarket" => 2260929,
            "warehouse" => 202082,
            "flatload" => 500000
        ),
        "Minneapolis" => Dict(
            "fastfoodrest" => 188368,
            "fullservicerest" => 330920,
            "hospital" => 8425063,
            "largehotel" => 2378872,
            "largeoffice" => 6306693,
            "mediumoffice" => 1005875,
            "midriseapartment" => 267383,
            "outpatient" => 1582701,
            "primaryschool" => 1022667,
            "retailstore" => 539203,
            "secondaryschool" => 2498647,
            "smallhotel" => 774571,
            "smalloffice" => 85921,
            "stripmall" => 511567,
            "supermarket" => 2034650,
            "warehouse" => 249332,
            "flatload" => 500000
        ),
        "Phoenix" => Dict(
            "fastfoodrest" => 216088,
            "fullservicerest" => 389739,
            "hospital" => 9265786,
            "largehotel" => 2990053,
            "largeoffice" => 7211666,
            "mediumoffice" => 1004988,
            "midriseapartment" => 378378,
            "outpatient" => 1849358,
            "primaryschool" => 1289084,
            "retailstore" => 593924,
            "secondaryschool" => 3503727,
            "smallhotel" => 881843,
            "smalloffice" => 104583,
            "stripmall" => 590954,
            "supermarket" => 2056195,
            "warehouse" => 241585,
            "flatload" => 500000
        ),
        "SanFrancisco" => Dict(
            "fastfoodrest" => 183953,
            "fullservicerest" => 317124,
            "hospital" => 7752817,
            "largehotel" => 2206880,
            "largeoffice" => 6085403,
            "mediumoffice" => 792199,
            "midriseapartment" => 229671,
            "outpatient" => 1394447,
            "primaryschool" => 1009369,
            "retailstore" => 449025,
            "secondaryschool" => 2327074,
            "smallhotel" => 698095,
            "smalloffice" => 78132,
            "stripmall" => 455802,
            "supermarket" => 1841655,
            "warehouse" => 185889,
            "flatload" => 500000
        ),
        "Seattle" => Dict(
            "fastfoodrest" => 184142,
            "fullservicerest" => 318741,
            "hospital" => 7912504,
            "largehotel" => 2212410,
            "largeoffice" => 6019271,
            "mediumoffice" => 878390,
            "midriseapartment" => 237242,
            "outpatient" => 1434195,
            "primaryschool" => 983498,
            "retailstore" => 455854,
            "secondaryschool" => 2282972,
            "smallhotel" => 693921,
            "smalloffice" => 79716,
            "stripmall" => 460449,
            "supermarket" => 1868973,
            "warehouse" => 210300,
            "flatload" => 500000
        ),
    )
    if !(buildingtype in default_buildings)
        throw(@error("buildingtype $(buildingtype) not in $(default_buildings)."))
    end

    if isempty(city)
        city = find_ashrae_zone_city(latitude, longitude)
    end

    if isnothing(annual_kwh)
        # Use FlatLoad annual_kwh from data for all types of FlatLoads because we don't have separate data for e.g. FlatLoad_16_7
        if occursin("FlatLoad", buildingtype)
            annual_kwh = annual_loads[city][lowercase("FlatLoad")]
        else
            annual_kwh = annual_loads[city][lowercase(buildingtype)]
        end
    end

    built_in_load("electric", city, buildingtype, year, annual_kwh, monthly_totals_kwh, nothing, normalized_profile)
end
