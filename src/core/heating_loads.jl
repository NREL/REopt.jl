# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************
struct DomesticHotWaterLoad
    loads_kw::Array{Real, 1}

    function DomesticHotWaterLoad(;
        doe_reference_name::String = "",
        city::String = "",
        blended_doe_reference_names::Array{String, 1} = String[],
        blended_doe_reference_percents::Array{<:Real,1} = Real[],
        annual_mmbtu::Union{Real, Nothing} = nothing,
        monthly_mmbtu::Array{<:Real,1} = Real[],
        # addressable_load_fraction,  # TODO
        fuel_loads_mmbtu_per_hour::Array{<:Real,1} = Real[],
        time_steps_per_hour::Int = 1,
        latitude::Float64=0.0,
        longitude::Float64=0.0
    )
        if length(fuel_loads_mmbtu_per_hour) > 0

            if !(length(fuel_loads_mmbtu_per_hour) / time_steps_per_hour ≈ 8760)
                @error "Provided domestic hot water load does not match the time_steps_per_hour."
            end

            loads_kw = fuel_loads_mmbtu_per_hour .* (MMBTU_TO_KWH * EXISTING_BOILER_EFFICIENCY)

        elseif !isempty(doe_reference_name)
            loads_kw = BuiltInDomesticHotWaterLoad(city, doe_reference_name, latitude, longitude, 2017, annual_mmbtu, monthly_mmbtu)

        elseif length(blended_doe_reference_names) > 1 && 
            length(blended_doe_reference_names) == length(blended_doe_reference_percents)
            loads_kw = blend_and_scale_doe_profiles(BuiltInDomesticHotWaterLoad, latitude, longitude, 2017, 
                                                    blended_doe_reference_names, blended_doe_reference_percents, city, 
                                                    annual_mmbtu, monthly_mmbtu)
        else
            error("Cannot construct DomesticHotWaterLoad. You must provide either [fuel_loads_mmbtu_per_hour], 
                [doe_reference_name, city],
                or [blended_doe_reference_names, blended_doe_reference_percents, city].")
        end

        if length(loads_kw) < 8760*time_steps_per_hour
            loads_kw = repeat(loads_kw, inner=Int(time_steps_per_hour / (length(loads_kw)/8760)))
            @info "Repeating domestic hot water loads in each hour to match the time_steps_per_hour."
        end

        new(
            loads_kw
        )
    end
end


struct SpaceHeatingLoad
    loads_kw::Array{Real, 1}

    function SpaceHeatingLoad(;
        doe_reference_name::String = "",
        city::String = "",
        blended_doe_reference_names::Array{String, 1} = String[],
        blended_doe_reference_percents::Array{<:Real,1} = Real[],
        annual_mmbtu::Union{Real, Nothing} = nothing,
        monthly_mmbtu::Array{<:Real,1} = Real[],
        # addressable_load_fraction,  # TODO
        fuel_loads_mmbtu_per_hour::Array{<:Real,1} = Real[],
        time_steps_per_hour::Int = 1,
        latitude::Float64=0.0,
        longitude::Float64=0.0
    )
        if length(fuel_loads_mmbtu_per_hour) > 0

            if !(length(fuel_loads_mmbtu_per_hour) / time_steps_per_hour ≈ 8760)
                @error "Provided space heating load does not match the time_steps_per_hour."
            end

            loads_kw = fuel_loads_mmbtu_per_hour .* (MMBTU_TO_KWH * EXISTING_BOILER_EFFICIENCY)

        elseif !isempty(doe_reference_name)
            loads_kw = BuiltInSpaceHeatingLoad(city, doe_reference_name, latitude, longitude, 2017, annual_mmbtu, monthly_mmbtu)

        elseif length(blended_doe_reference_names) > 1 && 
            length(blended_doe_reference_names) == length(blended_doe_reference_percents)
            loads_kw = blend_and_scale_doe_profiles(BuiltInSpaceHeatingLoad, latitude, longitude, 2017, 
                                                    blended_doe_reference_names, blended_doe_reference_percents, city, 
                                                    annual_mmbtu, monthly_mmbtu)
        else
            error("Cannot construct BuiltInSpaceHeatingLoad. You must provide either [fuel_loads_mmbtu_per_hour], 
                [doe_reference_name, city], 
                or [blended_doe_reference_names, blended_doe_reference_percents, city].")
        end

        if length(loads_kw) < 8760*time_steps_per_hour
            loads_kw = repeat(loads_kw, inner=Int(time_steps_per_hour / (length(loads_kw)/8760)))
            @info "Repeating space heating loads in each hour to match the time_steps_per_hour."
        end

        new(
            loads_kw
        )
    end
end


function BuiltInDomesticHotWaterLoad(
    city::String,
    buildingtype::String,
    latitude::Float64,
    longitude::Float64,
    year::Int,
    annual_mmbtu::Union{<:Real, Nothing}=nothing,
    monthly_mmbtu::Union{Vector{<:Real}, Nothing}=nothing
    )
    dhw_annual_mmbtu = Dict(
        "Miami" => Dict(
            "FastFoodRest" => 53.47209411,
            "FullServiceRest" => 158.0518043,
            "Hospital" => 442.7295435,
            "LargeHotel" => 3713.248373,
            "LargeOffice" => 127.9412792,
            "MediumOffice" => 22.09603477,
            "MidriseApartment" => 158.0580017,
            "Outpatient" => 27.60091429,
            "PrimarySchool" => 105.3179165,
            "RetailStore" => 0.0,
            "SecondarySchool" => 250.1299246,
            "SmallHotel" => 242.232695,
            "SmallOffice" => 9.891779415,
            "StripMall" => 0.0,
            "Supermarket" => 17.94985187,
            "warehouse" => 0.0,
            "FlatLoad" => 333.0450133
        ),
        "Houston" => Dict(
            "FastFoodRest" => 62.56835989,
            "FullServiceRest" => 188.292814,
            "Hospital" => 530.6352726,
            "LargeHotel" => 4685.666667,
            "LargeOffice" => 160.8917808,
            "MediumOffice" => 25.9266894,
            "MidriseApartment" => 199.2544784,
            "Outpatient" => 32.87691943,
            "PrimarySchool" => 128.0705362,
            "RetailStore" => 0.0,
            "SecondarySchool" => 314.7654465,
            "SmallHotel" => 290.6293673,
            "SmallOffice" => 10.27839347,
            "StripMall" => 0.0,
            "Supermarket" => 19.86608717,
            "warehouse" => 0.0,
            "FlatLoad" => 415.6076756
        ),
        "Phoenix" => Dict(
            "FastFoodRest" => 57.34025418,
            "FullServiceRest" => 170.9086319,
            "Hospital" => 480.098265,
            "LargeHotel" => 4127.191046,
            "LargeOffice" => 141.8507451,
            "MediumOffice" => 23.71397275,
            "MidriseApartment" => 175.5949563,
            "Outpatient" => 29.83372212,
            "PrimarySchool" => 116.811664,
            "RetailStore" => 0.0,
            "SecondarySchool" => 285.2339344,
            "SmallHotel" => 262.8487714,
            "SmallOffice" => 10.05557471,
            "StripMall" => 0.0,
            "Supermarket" => 18.7637822,
            "warehouse" => 0.0,
            "FlatLoad" => 368.7653325
        ),
        "Atlanta" => Dict(
            "FastFoodRest" => 71.33170579,
            "FullServiceRest" => 217.4332205,
            "Hospital" => 615.3498557,
            "LargeHotel" => 5622.340656,
            "LargeOffice" => 192.7164525,
            "MediumOffice" => 29.62182675,
            "MidriseApartment" => 238.9315749,
            "Outpatient" => 37.9759973,
            "PrimarySchool" => 148.8362119,
            "RetailStore" => 0.0,
            "SecondarySchool" => 372.2083434,
            "SmallHotel" => 337.2688069,
            "SmallOffice" => 10.65138846,
            "StripMall" => 0.0,
            "Supermarket" => 21.71038069,
            "warehouse" => 0.0,
            "FlatLoad" => 494.7735263
        ),
        "LasVegas" => Dict(
            "FastFoodRest" => 63.63848459,
            "FullServiceRest" => 191.8494897,
            "Hospital" => 540.9697668,
            "LargeHotel" => 4800.331564,
            "LargeOffice" => 164.7154124,
            "MediumOffice" => 26.36796732,
            "MidriseApartment" => 204.1120165,
            "Outpatient" => 33.48190098,
            "PrimarySchool" => 131.9651451,
            "RetailStore" => 0.0,
            "SecondarySchool" => 327.441087,
            "SmallHotel" => 296.3578765,
            "SmallOffice" => 10.32392915,
            "StripMall" => 0.0,
            "Supermarket" => 20.08676069,
            "warehouse" => 0.0,
            "FlatLoad" => 425.7275876
        ),
        "LosAngeles" => Dict(
            "FastFoodRest" => 69.63212501,
            "FullServiceRest" => 211.7827529,
            "Hospital" => 598.9350422,
            "LargeHotel" => 5440.174033,
            "LargeOffice" => 186.6199083,
            "MediumOffice" => 28.91483286,
            "MidriseApartment" => 231.215325,
            "Outpatient" => 37.00823296,
            "PrimarySchool" => 142.8059487,
            "RetailStore" => 0.0,
            "SecondarySchool" => 352.7467563,
            "SmallHotel" => 328.1935523,
            "SmallOffice" => 10.58011717,
            "StripMall" => 0.0,
            "Supermarket" => 21.35337379,
            "warehouse" => 0.0,
            "FlatLoad" => 478.7476251
        ),
        "SanFrancisco" => Dict(
            "FastFoodRest" => 77.13092952,
            "FullServiceRest" => 236.7180594,
            "Hospital" => 671.40531,
            "LargeHotel" => 6241.842643,
            "LargeOffice" => 213.8445094,
            "MediumOffice" => 32.07909301,
            "MidriseApartment" => 265.1697301,
            "Outpatient" => 41.35500136,
            "PrimarySchool" => 160.4507431,
            "RetailStore" => 0.0,
            "SecondarySchool" => 401.395655,
            "SmallHotel" => 368.0979112,
            "SmallOffice" => 10.90004379,
            "StripMall" => 0.0,
            "Supermarket" => 22.9292287,
            "warehouse" => 0.0,
            "FlatLoad" => 546.4574286
        ),
        "Baltimore" => Dict(
            "FastFoodRest" => 78.2191761,
            "FullServiceRest" => 240.338156,
            "Hospital" => 681.9322322,
            "LargeHotel" => 6358.710286,
            "LargeOffice" => 217.7306132,
            "MediumOffice" => 32.52815422,
            "MidriseApartment" => 270.1195541,
            "Outpatient" => 41.96148216,
            "PrimarySchool" => 165.3116185,
            "RetailStore" => 0.0,
            "SecondarySchool" => 417.9512972,
            "SmallHotel" => 373.906416,
            "SmallOffice" => 10.94554028,
            "StripMall" => 0.0,
            "Supermarket" => 23.15795696,
            "warehouse" => 0.0,
            "FlatLoad" => 557.0507802
        ),
        "Albuquerque" => Dict(
            "FastFoodRest" => 76.9149868,
            "FullServiceRest" => 235.9992545,
            "Hospital" => 669.3128607,
            "LargeHotel" => 6219.08303,
            "LargeOffice" => 212.9944774,
            "MediumOffice" => 31.97726287,
            "MidriseApartment" => 264.2063457,
            "Outpatient" => 41.20639013,
            "PrimarySchool" => 162.1556119,
            "RetailStore" => 0.0,
            "SecondarySchool" => 409.1649863,
            "SmallHotel" => 366.9712928,
            "SmallOffice" => 10.88949351,
            "StripMall" => 0.0,
            "Supermarket" => 22.88525618,
            "warehouse" => 0.0,
            "FlatLoad" => 545.235078
        ),
        "Seattle" => Dict(
            "FastFoodRest" => 81.80231236,
            "FullServiceRest" => 252.2609525,
            "Hospital" => 716.6111323,
            "LargeHotel" => 6741.736717,
            "LargeOffice" => 230.8057849,
            "MediumOffice" => 34.04746055,
            "MidriseApartment" => 286.3412104,
            "Outpatient" => 44.07342164,
            "PrimarySchool" => 172.0233322,
            "RetailStore" => 0.0,
            "SecondarySchool" => 434.0806311,
            "SmallHotel" => 392.968915,
            "SmallOffice" => 11.09863592,
            "StripMall" => 0.0,
            "Supermarket" => 23.91178737,
            "warehouse" => 0.0,
            "FlatLoad" => 588.8601433
        ),
        "Chicago" => Dict(
            "FastFoodRest" => 84.2645196,
            "FullServiceRest" => 260.4454844,
            "Hospital" => 740.4172516,
            "LargeHotel" => 7005.083356,
            "LargeOffice" => 239.7065959,
            "MediumOffice" => 35.08184587,
            "MidriseApartment" => 297.4938584,
            "Outpatient" => 45.49600079,
            "PrimarySchool" => 179.4639347,
            "RetailStore" => 0.0,
            "SecondarySchool" => 456.8817409,
            "SmallHotel" => 406.0751832,
            "SmallOffice" => 11.2033023,
            "StripMall" => 0.0,
            "Supermarket" => 24.4292392,
            "warehouse" => 0.0,
            "FlatLoad" => 611.6276445
        ),
        "Boulder" => Dict(
            "FastFoodRest" => 83.95201542,
            "FullServiceRest" => 259.3997752,
            "Hospital" => 737.372005,
            "LargeHotel" => 6971.32924,
            "LargeOffice" => 238.572519,
            "MediumOffice" => 34.9486709,
            "MidriseApartment" => 296.06471,
            "Outpatient" => 45.31437164,
            "PrimarySchool" => 178.3378526,
            "RetailStore" => 0.0,
            "SecondarySchool" => 453.228537,
            "SmallHotel" => 404.4154946,
            "SmallOffice" => 11.18970855,
            "StripMall" => 0.0,
            "Supermarket" => 24.36505320,
            "warehouse" => 0.0,
            "FlatLoad" => 608.6556221
        ),
        "Minneapolis" => Dict(
            "FastFoodRest" => 89.48929949,
            "FullServiceRest" => 277.8184269,
            "Hospital" => 790.9262388,
            "LargeHotel" => 7563.607619,
            "LargeOffice" => 258.6874644,
            "MediumOffice" => 37.28641454,
            "MidriseApartment" => 321.1473562,
            "Outpatient" => 48.51884975,
            "PrimarySchool" => 191.9480118,
            "RetailStore" => 0.0,
            "SecondarySchool" => 491.5554097,
            "SmallHotel" => 433.8738637,
            "SmallOffice" => 11.42620649,
            "StripMall" => 0.0,
            "Supermarket" => 25.53218144,
            "warehouse" => 0.0,
            "FlatLoad" => 658.8635839
        ),
        "Helena" => Dict(
            "FastFoodRest" => 90.44011877,
            "FullServiceRest" => 280.9757902,
            "Hospital" => 800.0940058,
            "LargeHotel" => 7665.023574,
            "LargeOffice" => 262.1461576,
            "MediumOffice" => 37.68905029,
            "MidriseApartment" => 325.4421541,
            "Outpatient" => 49.09222188,
            "PrimarySchool" => 193.4573283,
            "RetailStore" => 0.0,
            "SecondarySchool" => 494.7393735,
            "SmallHotel" => 438.9398731,
            "SmallOffice" => 11.46564268,
            "StripMall" => 0.0,
            "Supermarket" => 25.72866824,
            "warehouse" => 0.0,
            "FlatLoad" => 667.2021224
        ),
        "Duluth" => Dict(
            "FastFoodRest" => 98.10641517,
            "FullServiceRest" => 306.4772907,
            "Hospital" => 874.2611723,
            "LargeHotel" => 8484.906093,
            "LargeOffice" => 290.0193773,
            "MediumOffice" => 40.92475821,
            "MidriseApartment" => 360.161261,
            "Outpatient" => 53.53681127,
            "PrimarySchool" => 211.2386551,
            "RetailStore" => 0.0,
            "SecondarySchool" => 543.3733772,
            "SmallHotel" => 479.7414481,
            "SmallOffice" => 11.79316054,
            "StripMall" => 0.0,
            "Supermarket" => 27.3451629,
            "warehouse" => 0.0,
            "FlatLoad" => 736.3678114
        ),
        "Fairbanks" => Dict(
            "FastFoodRest" => 108.5335945,
            "FullServiceRest" => 341.1572799,
            "Hospital" => 975.1062178,
            "LargeHotel" => 9600.267161,
            "LargeOffice" => 327.8820873,
            "MediumOffice" => 45.32138512,
            "MidriseApartment" => 407.3910855,
            "Outpatient" => 59.6203514,
            "PrimarySchool" => 234.2595741,
            "RetailStore" => 0.0,
            "SecondarySchool" => 604.6838786,
            "SmallHotel" => 535.2525234,
            "SmallOffice" => 12.23744003,
            "StripMall" => 0.0,
            "Supermarket" => 29.53958045,
            "warehouse" => 0.0,
            "FlatLoad" => 830.07826
        )
    )
    if isempty(city)
        city = find_ashrae_zone_city(latitude, longitude)
    end
    if !(buildingtype in default_buildings)
        error("buildingtype $(buildingtype) not in $(default_buildings).")
    end
    if isnothing(annual_mmbtu)
        annual_mmbtu = dhw_annual_mmbtu[city][buildingtype]
    end
    built_in_load("domestic_hot_water", city, buildingtype, year, annual_mmbtu, monthly_mmbtu)
end


function BuiltInSpaceHeatingLoad(
    city::String,
    buildingtype::String,
    latitude::Float64,
    longitude::Float64,
    year::Int,
    annual_mmbtu::Union{<:Real, Nothing}=nothing,
    monthly_mmbtu::Union{Vector{<:Real}, Nothing}=nothing,
    )
    spaceheating_annual_mmbtu = Dict(
        "Miami" => Dict(
            "FastFoodRest" => 5.426780867,
            "FullServiceRest" => 12.03181471,
            "Hospital" => 6248.413294,
            "LargeHotel" => 198.0691407,
            "LargeOffice" => 168.9731637,
            "MediumOffice" => 0.036985655,
            "MidriseApartment" => 38.70606161,
            "Outpatient" => 2559.185872,
            "PrimarySchool" => 49.78021153,
            "RetailStore" => 12.12015432,
            "SecondarySchool" => 203.5185485,
            "SmallHotel" => 9.098564901,
            "SmallOffice" => 0.312524873,
            "StripMall" => 20.73216748,
            "Supermarket" => 101.2785324,
            "warehouse" => 56.0796017,
            "FlatLoad" => 605.2352137
        ),
        "Houston" => Dict(
            "FastFoodRest" => 85.49111065,
            "FullServiceRest" => 199.7942842,
            "Hospital" => 8732.10385,
            "LargeHotel" => 1307.035548,
            "LargeOffice" => 2229.971744,
            "MediumOffice" => 16.25994314,
            "MidriseApartment" => 386.0269973,
            "Outpatient" => 2829.324307,
            "PrimarySchool" => 469.2532935,
            "RetailStore" => 289.0470815,
            "SecondarySchool" => 2011.1678969999998,
            "SmallHotel" => 108.9825885,
            "SmallOffice" => 19.55157672,
            "StripMall" => 292.23235389999996,
            "Supermarket" => 984.7374347000001,
            "warehouse" => 475.9377273,
            "FlatLoad" => 1277.307359
        ),
        "Phoenix" => Dict(
            "FastFoodRest" => 57.89972381,
            "FullServiceRest" => 147.2569493,
            "Hospital" => 9382.021026,
            "LargeHotel" => 896.790817,
            "LargeOffice" => 1584.061452,
            "MediumOffice" => 1.922551528,
            "MidriseApartment" => 290.9887152,
            "Outpatient" => 3076.340876,
            "PrimarySchool" => 305.573525,
            "RetailStore" => 208.66330580000002,
            "SecondarySchool" => 1400.638544,
            "SmallHotel" => 83.98084516,
            "SmallOffice" => 9.988210938,
            "StripMall" => 230.16060699999997,
            "Supermarket" => 972.3008295,
            "warehouse" => 362.42249280000004,
            "FlatLoad" => 1188.188154
        ),
        "Atlanta" => Dict(
            "FastFoodRest" => 168.8402371,
            "FullServiceRest" => 379.5865464,
            "Hospital" => 10467.659959999999,
            "LargeHotel" => 2427.6589879999997,
            "LargeOffice" => 3624.593975,
            "MediumOffice" => 49.00635733,
            "MidriseApartment" => 718.9316697,
            "Outpatient" => 3186.250588,
            "PrimarySchool" => 931.7212450999999,
            "RetailStore" => 627.2489826000001,
            "SecondarySchool" => 3968.4936420000004,
            "SmallHotel" => 202.26124219999997,
            "SmallOffice" => 42.74797302,
            "StripMall" => 615.2240506,
            "Supermarket" => 1880.5304489999999,
            "warehouse" => 930.9449202,
            "FlatLoad" => 1888.856302
        ),
        "LasVegas" => Dict(
            "FastFoodRest" => 100.0877773,
            "FullServiceRest" => 247.21791319999997,
            "Hospital" => 9100.302056,
            "LargeHotel" => 1500.581408,
            "LargeOffice" => 2479.152321,
            "MediumOffice" => 5.220181581,
            "MidriseApartment" => 487.43122850000003,
            "Outpatient" => 2924.8220460000002,
            "PrimarySchool" => 499.6562223,
            "RetailStore" => 386.0185744,
            "SecondarySchool" => 2277.7410649999997,
            "SmallHotel" => 138.4427074,
            "SmallOffice" => 19.16330622,
            "StripMall" => 389.30494280000005,
            "Supermarket" => 1479.302604,
            "warehouse" => 579.7671637999999,
            "FlatLoad" => 1413.3882199999998
        ),
        "LosAngeles" => Dict(
            "FastFoodRest" => 40.90390152,
            "FullServiceRest" => 97.94277036,
            "Hospital" => 10346.1713,
            "LargeHotel" => 707.848762,
            "LargeOffice" => 1458.148818,
            "MediumOffice" => 0.12342009699999999,
            "MidriseApartment" => 265.2851759,
            "Outpatient" => 3417.120585,
            "PrimarySchool" => 318.73600980000003,
            "RetailStore" => 175.104083,
            "SecondarySchool" => 1198.276619,
            "SmallHotel" => 72.42852638,
            "SmallOffice" => 5.898878347,
            "StripMall" => 193.18730269999998,
            "Supermarket" => 1040.273464,
            "warehouse" => 323.96697819999997,
            "FlatLoad" => 1228.8385369999999
        ),
        "SanFrancisco" => Dict(
            "FastFoodRest" => 127.22328700000001,
            "FullServiceRest" => 362.48645889999995,
            "Hospital" => 11570.9155,
            "LargeHotel" => 1713.3629670000003,
            "LargeOffice" => 2690.1191,
            "MediumOffice" => 3.8159670660000002,
            "MidriseApartment" => 648.4472797999999,
            "Outpatient" => 3299.0539519999998,
            "PrimarySchool" => 818.2159102,
            "RetailStore" => 569.8081034,
            "SecondarySchool" => 3414.148347,
            "SmallHotel" => 189.0244446,
            "SmallOffice" => 27.53039453,
            "StripMall" => 526.2320428,
            "Supermarket" => 2301.616069,
            "warehouse" => 675.6758453,
            "FlatLoad" => 1808.604729
        ),
        "Baltimore" => Dict(
            "FastFoodRest" => 305.2671204,
            "FullServiceRest" => 657.1337578,
            "Hospital" => 11253.61694,
            "LargeHotel" => 3731.0254619999996,
            "LargeOffice" => 5109.311943,
            "MediumOffice" => 116.8101842,
            "MidriseApartment" => 1132.964052,
            "Outpatient" => 3285.227941,
            "PrimarySchool" => 1428.239177,
            "RetailStore" => 1068.034778,
            "SecondarySchool" => 6557.634924,
            "SmallHotel" => 346.3683857,
            "SmallOffice" => 63.29818348,
            "StripMall" => 1075.39546,
            "Supermarket" => 2929.182261,
            "warehouse" => 1568.722061,
            "FlatLoad" => 2539.2645399999997
        ),
        "Albuquerque" => Dict(
            "FastFoodRest" => 199.73581399999998,
            "FullServiceRest" => 398.5712205,
            "Hospital" => 8371.240776999999,
            "LargeHotel" => 2750.8382260000003,
            "LargeOffice" => 3562.0023950000004,
            "MediumOffice" => 47.49307973,
            "MidriseApartment" => 805.0965778,
            "Outpatient" => 2971.868562,
            "PrimarySchool" => 981.4176700999999,
            "RetailStore" => 755.4523907,
            "SecondarySchool" => 4338.227865999999,
            "SmallHotel" => 232.2194443,
            "SmallOffice" => 43.25360481,
            "StripMall" => 760.0982018,
            "Supermarket" => 2302.228741,
            "warehouse" => 1151.250885,
            "FlatLoad" => 1854.437216
        ),
        "Seattle" => Dict(
            "FastFoodRest" => 255.5992711,
            "FullServiceRest" => 627.5634984000001,
            "Hospital" => 11935.157290000001,
            "LargeHotel" => 3343.683348,
            "LargeOffice" => 5266.970348,
            "MediumOffice" => 28.97979768,
            "MidriseApartment" => 1117.5465470000001,
            "Outpatient" => 3468.128914,
            "PrimarySchool" => 1263.541878,
            "RetailStore" => 952.2758742000001,
            "SecondarySchool" => 6367.850187,
            "SmallHotel" => 310.8087307,
            "SmallOffice" => 49.34878545,
            "StripMall" => 969.1074739000001,
            "Supermarket" => 3004.1844929999997,
            "warehouse" => 1137.398514,
            "FlatLoad" => 2506.1340600000003
        ),
        "Chicago" => Dict(
            "FastFoodRest" => 441.93439000000006,
            "FullServiceRest" => 888.3312571,
            "Hospital" => 12329.57943,
            "LargeHotel" => 5104.848129,
            "LargeOffice" => 7706.028917000001,
            "MediumOffice" => 216.01411800000002,
            "MidriseApartment" => 1482.040156,
            "Outpatient" => 3506.5381090000005,
            "PrimarySchool" => 2006.0002120000001,
            "RetailStore" => 1472.8704380000001,
            "SecondarySchool" => 8962.172873,
            "SmallHotel" => 479.4653436000001,
            "SmallOffice" => 94.19308949,
            "StripMall" => 1497.556168,
            "Supermarket" => 3696.2112950000005,
            "warehouse" => 2256.477231,
            "FlatLoad" => 3258.766323
        ),
        "Boulder" => Dict(
            "FastFoodRest" => 306.8980525,
            "FullServiceRest" => 642.8843574,
            "Hospital" => 9169.381845,
            "LargeHotel" => 3975.1080020000004,
            "LargeOffice" => 5027.882454,
            "MediumOffice" => 124.26913059999998,
            "MidriseApartment" => 1098.944993,
            "Outpatient" => 3087.969786,
            "PrimarySchool" => 1356.396807,
            "RetailStore" => 1086.9187570000001,
            "SecondarySchool" => 6268.036872,
            "SmallHotel" => 342.77800099999996,
            "SmallOffice" => 65.95714912,
            "StripMall" => 1093.093638,
            "Supermarket" => 2966.790122,
            "warehouse" => 1704.8648210000001,
            "FlatLoad" => 2394.8859239999997
        ),
        "Minneapolis" => Dict(
            "FastFoodRest" => 588.8854722,
            "FullServiceRest" => 1121.229499,
            "Hospital" => 13031.2313,
            "LargeHotel" => 6359.946704,
            "LargeOffice" => 10199.279129999999,
            "MediumOffice" => 394.1525556,
            "MidriseApartment" => 1814.148381,
            "Outpatient" => 3661.1462229999997,
            "PrimarySchool" => 2600.964302,
            "RetailStore" => 1869.8106289999998,
            "SecondarySchool" => 11963.323859999999,
            "SmallHotel" => 618.0427338999999,
            "SmallOffice" => 128.12525349999999,
            "StripMall" => 1952.731917,
            "Supermarket" => 4529.776664,
            "warehouse" => 3231.223746,
            "FlatLoad" => 4004.001148
        ),
        "Helena" => Dict(
            "FastFoodRest" => 468.8276835,
            "FullServiceRest" => 934.8994934,
            "Hospital" => 10760.57411,
            "LargeHotel" => 5554.910785,
            "LargeOffice" => 7373.056709,
            "MediumOffice" => 239.8330306,
            "MidriseApartment" => 1531.102079,
            "Outpatient" => 3390.42972,
            "PrimarySchool" => 2097.777112,
            "RetailStore" => 1494.85988,
            "SecondarySchool" => 9535.484059,
            "SmallHotel" => 499.85992930000003,
            "SmallOffice" => 98.85818175,
            "StripMall" => 1604.0043970000002,
            "Supermarket" => 3948.5338049999996,
            "warehouse" => 2504.784991,
            "FlatLoad" => 3252.362248
        ),
        "Duluth" => Dict(
            "FastFoodRest" => 738.1353594999999,
            "FullServiceRest" => 1400.36692,
            "Hospital" => 14179.84149,
            "LargeHotel" => 7781.9012760000005,
            "LargeOffice" => 12504.64187,
            "MediumOffice" => 468.2112216,
            "MidriseApartment" => 2204.85149,
            "Outpatient" => 3774.3233130000003,
            "PrimarySchool" => 3160.1200719999997,
            "RetailStore" => 2298.8242920000002,
            "SecondarySchool" => 14468.64346,
            "SmallHotel" => 772.5386662000001,
            "SmallOffice" => 155.8350887,
            "StripMall" => 2411.847491,
            "Supermarket" => 5587.977185,
            "warehouse" => 3962.122014,
            "FlatLoad" => 4741.886326
        ),
        "Fairbanks" => Dict(
            "FastFoodRest" => 1245.3608279999999,
            "FullServiceRest" => 2209.293209,
            "Hospital" => 20759.042680000002,
            "LargeHotel" => 12298.7791,
            "LargeOffice" => 23214.51532,
            "MediumOffice" => 949.8812392000001,
            "MidriseApartment" => 3398.039504,
            "Outpatient" => 4824.076322999999,
            "PrimarySchool" => 6341.861225,
            "RetailStore" => 3869.670979,
            "SecondarySchool" => 25619.149269999998,
            "SmallHotel" => 1264.41064,
            "SmallOffice" => 297.08593010000004,
            "StripMall" => 3934.89178,
            "Supermarket" => 8515.422039000001,
            "warehouse" => 6882.6512680000005,
            "FlatLoad" => 7851.508208
        )
    )
    if isempty(city)
        city = find_ashrae_zone_city(latitude, longitude)
    end
    if !(buildingtype in default_buildings)
        error("buildingtype $(buildingtype) not in $(default_buildings).")
    end
    if isnothing(annual_mmbtu)
        annual_mmbtu = spaceheating_annual_mmbtu[city][buildingtype]
    end
    built_in_load("space_heating", city, buildingtype, year, annual_mmbtu, monthly_mmbtu)
end