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
        loads_mmbtu_per_hour::Array{<:Real,1} = Real[],
        time_steps_per_hour::Int = 1,
        latitude::Float64=0.0,
        longitude::Float64=0.0
    )
        if length(loads_mmbtu_per_hour) > 0

            if !(length(loads_mmbtu_per_hour) / time_steps_per_hour ≈ 8760)
                @error "Provided domestic hot water load does not match the time_steps_per_hour."
            end

        elseif !isempty(doe_reference_name)
            loads_mmbtu_per_hour = BuiltInDomesticHotWaterLoad(city, doe_reference_name, latitude, longitude, 2017, annual_mmbtu, monthly_mmbtu)

        elseif length(blended_doe_reference_names) > 1 && 
            length(blended_doe_reference_names) == length(blended_doe_reference_percents)
            loads_mmbtu_per_hour = blend_and_scale_doe_profiles(BuiltInDomesticHotWaterLoad, latitude, longitude, 2017, 
                                                    blended_doe_reference_names, blended_doe_reference_percents, city, 
                                                    annual_mmbtu, monthly_mmbtu)
        else
            error("Cannot construct DomesticHotWaterLoad. You must provide either [loads_mmbtu_per_hour], 
                [doe_reference_name, city],
                or [blended_doe_reference_names, blended_doe_reference_percents, city].")
        end

        loads_kw = loads_mmbtu_per_hour * mmbtu_to_kwh

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
        loads_mmbtu_per_hour::Array{<:Real,1} = Real[],
        time_steps_per_hour::Int = 1,
        latitude::Float64=0.0,
        longitude::Float64=0.0
    )
        if length(loads_mmbtu_per_hour) > 0

            if !(length(loads_mmbtu_per_hour) / time_steps_per_hour ≈ 8760)
                @error "Provided space heating load does not match the time_steps_per_hour."
            end

        elseif !isempty(doe_reference_name)
            loads_mmbtu_per_hour = BuiltInSpaceHeatingLoad(city, doe_reference_name, latitude, longitude, 2017, annual_mmbtu, monthly_mmbtu)

        elseif length(blended_doe_reference_names) > 1 && 
            length(blended_doe_reference_names) == length(blended_doe_reference_percents)
            loads_mmbtu_per_hour = blend_and_scale_doe_profiles(BuiltInSpaceHeatingLoad, latitude, longitude, 2017, 
                                                    blended_doe_reference_names, blended_doe_reference_percents, city, 
                                                    annual_mmbtu, monthly_mmbtu)
        else
            error("Cannot construct BuiltInSpaceHeatingLoad. You must provide either [loads_mmbtu_per_hour], 
                [doe_reference_name, city], 
                or [blended_doe_reference_names, blended_doe_reference_percents, city].")
        end

        loads_kw = loads_mmbtu_per_hour * mmbtu_to_kwh

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
    monthly_mmbtu::Union{<:Real, Vector{<:Real}}=nothing,
    )
    dhw_annual_mmbtu = Dict(
        "Miami" => Dict(
            "fastfoodrest" => 53.47209411,
            "fullservicerest" => 158.0518043,
            "hospital" => 442.7295435,
            "largehotel" => 3713.248373,
            "largeoffice" => 127.9412792,
            "mediumoffice" => 22.09603477,
            "midriseapartment" => 158.0580017,
            "outpatient" => 27.60091429,
            "primaryschool" => 105.3179165,
            "retailstore" => 0.0,
            "secondaryschool" => 250.1299246,
            "smallhotel" => 242.232695,
            "smalloffice" => 9.891779415,
            "stripmall" => 0.0,
            "supermarket" => 17.94985187,
            "warehouse" => 0.0,
            "flatload" => 333.0450133
        ),
        "Houston" => Dict(
            "fastfoodrest" => 62.56835989,
            "fullservicerest" => 188.292814,
            "hospital" => 530.6352726,
            "largehotel" => 4685.666667,
            "largeoffice" => 160.8917808,
            "mediumoffice" => 25.9266894,
            "midriseapartment" => 199.2544784,
            "outpatient" => 32.87691943,
            "primaryschool" => 128.0705362,
            "retailstore" => 0.0,
            "secondaryschool" => 314.7654465,
            "smallhotel" => 290.6293673,
            "smalloffice" => 10.27839347,
            "stripmall" => 0.0,
            "supermarket" => 19.86608717,
            "warehouse" => 0.0,
            "flatload" => 415.6076756
        ),
        "Phoenix" => Dict(
            "fastfoodrest" => 57.34025418,
            "fullservicerest" => 170.9086319,
            "hospital" => 480.098265,
            "largehotel" => 4127.191046,
            "largeoffice" => 141.8507451,
            "mediumoffice" => 23.71397275,
            "midriseapartment" => 175.5949563,
            "outpatient" => 29.83372212,
            "primaryschool" => 116.811664,
            "retailstore" => 0.0,
            "secondaryschool" => 285.2339344,
            "smallhotel" => 262.8487714,
            "smalloffice" => 10.05557471,
            "stripmall" => 0.0,
            "supermarket" => 18.7637822,
            "warehouse" => 0.0,
            "flatload" => 368.7653325
        ),
        "Atlanta" => Dict(
            "fastfoodrest" => 71.33170579,
            "fullservicerest" => 217.4332205,
            "hospital" => 615.3498557,
            "largehotel" => 5622.340656,
            "largeoffice" => 192.7164525,
            "mediumoffice" => 29.62182675,
            "midriseapartment" => 238.9315749,
            "outpatient" => 37.9759973,
            "primaryschool" => 148.8362119,
            "retailstore" => 0.0,
            "secondaryschool" => 372.2083434,
            "smallhotel" => 337.2688069,
            "smalloffice" => 10.65138846,
            "stripmall" => 0.0,
            "supermarket" => 21.71038069,
            "warehouse" => 0.0,
            "flatload" => 494.7735263
        ),
        "LasVegas" => Dict(
            "fastfoodrest" => 63.63848459,
            "fullservicerest" => 191.8494897,
            "hospital" => 540.9697668,
            "largehotel" => 4800.331564,
            "largeoffice" => 164.7154124,
            "mediumoffice" => 26.36796732,
            "midriseapartment" => 204.1120165,
            "outpatient" => 33.48190098,
            "primaryschool" => 131.9651451,
            "retailstore" => 0.0,
            "secondaryschool" => 327.441087,
            "smallhotel" => 296.3578765,
            "smalloffice" => 10.32392915,
            "stripmall" => 0.0,
            "supermarket" => 20.08676069,
            "warehouse" => 0.0,
            "flatload" => 425.7275876
        ),
        "LosAngeles" => Dict(
            "fastfoodrest" => 69.63212501,
            "fullservicerest" => 211.7827529,
            "hospital" => 598.9350422,
            "largehotel" => 5440.174033,
            "largeoffice" => 186.6199083,
            "mediumoffice" => 28.91483286,
            "midriseapartment" => 231.215325,
            "outpatient" => 37.00823296,
            "primaryschool" => 142.8059487,
            "retailstore" => 0.0,
            "secondaryschool" => 352.7467563,
            "smallhotel" => 328.1935523,
            "smalloffice" => 10.58011717,
            "stripmall" => 0.0,
            "supermarket" => 21.35337379,
            "warehouse" => 0.0,
            "flatload" => 478.7476251
        ),
        "SanFrancisco" => Dict(
            "fastfoodrest" => 77.13092952,
            "fullservicerest" => 236.7180594,
            "hospital" => 671.40531,
            "largehotel" => 6241.842643,
            "largeoffice" => 213.8445094,
            "mediumoffice" => 32.07909301,
            "midriseapartment" => 265.1697301,
            "outpatient" => 41.35500136,
            "primaryschool" => 160.4507431,
            "retailstore" => 0.0,
            "secondaryschool" => 401.395655,
            "smallhotel" => 368.0979112,
            "smalloffice" => 10.90004379,
            "stripmall" => 0.0,
            "supermarket" => 22.9292287,
            "warehouse" => 0.0,
            "flatload" => 546.4574286
        ),
        "Baltimore" => Dict(
            "fastfoodrest" => 78.2191761,
            "fullservicerest" => 240.338156,
            "hospital" => 681.9322322,
            "largehotel" => 6358.710286,
            "largeoffice" => 217.7306132,
            "mediumoffice" => 32.52815422,
            "midriseapartment" => 270.1195541,
            "outpatient" => 41.96148216,
            "primaryschool" => 165.3116185,
            "retailstore" => 0.0,
            "secondaryschool" => 417.9512972,
            "smallhotel" => 373.906416,
            "smalloffice" => 10.94554028,
            "stripmall" => 0.0,
            "supermarket" => 23.15795696,
            "warehouse" => 0.0,
            "flatload" => 557.0507802
        ),
        "Albuquerque" => Dict(
            "fastfoodrest" => 76.9149868,
            "fullservicerest" => 235.9992545,
            "hospital" => 669.3128607,
            "largehotel" => 6219.08303,
            "largeoffice" => 212.9944774,
            "mediumoffice" => 31.97726287,
            "midriseapartment" => 264.2063457,
            "outpatient" => 41.20639013,
            "primaryschool" => 162.1556119,
            "retailstore" => 0.0,
            "secondaryschool" => 409.1649863,
            "smallhotel" => 366.9712928,
            "smalloffice" => 10.88949351,
            "stripmall" => 0.0,
            "supermarket" => 22.88525618,
            "warehouse" => 0.0,
            "flatload" => 545.235078
        ),
        "Seattle" => Dict(
            "fastfoodrest" => 81.80231236,
            "fullservicerest" => 252.2609525,
            "hospital" => 716.6111323,
            "largehotel" => 6741.736717,
            "largeoffice" => 230.8057849,
            "mediumoffice" => 34.04746055,
            "midriseapartment" => 286.3412104,
            "outpatient" => 44.07342164,
            "primaryschool" => 172.0233322,
            "retailstore" => 0.0,
            "secondaryschool" => 434.0806311,
            "smallhotel" => 392.968915,
            "smalloffice" => 11.09863592,
            "stripmall" => 0.0,
            "supermarket" => 23.91178737,
            "warehouse" => 0.0,
            "flatload" => 588.8601433
        ),
        "Chicago" => Dict(
            "fastfoodrest" => 84.2645196,
            "fullservicerest" => 260.4454844,
            "hospital" => 740.4172516,
            "largehotel" => 7005.083356,
            "largeoffice" => 239.7065959,
            "mediumoffice" => 35.08184587,
            "midriseapartment" => 297.4938584,
            "outpatient" => 45.49600079,
            "primaryschool" => 179.4639347,
            "retailstore" => 0.0,
            "secondaryschool" => 456.8817409,
            "smallhotel" => 406.0751832,
            "smalloffice" => 11.2033023,
            "stripmall" => 0.0,
            "supermarket" => 24.4292392,
            "warehouse" => 0.0,
            "flatload" => 611.6276445
        ),
        "Boulder" => Dict(
            "fastfoodrest" => 83.95201542,
            "fullservicerest" => 259.3997752,
            "hospital" => 737.372005,
            "largehotel" => 6971.32924,
            "largeoffice" => 238.572519,
            "mediumoffice" => 34.9486709,
            "midriseapartment" => 296.06471,
            "outpatient" => 45.31437164,
            "primaryschool" => 178.3378526,
            "retailstore" => 0.0,
            "secondaryschool" => 453.228537,
            "smallhotel" => 404.4154946,
            "smalloffice" => 11.18970855,
            "stripmall" => 0.0,
            "supermarket" => 24.36505320,
            "warehouse" => 0.0,
            "flatload" => 608.6556221
        ),
        "Minneapolis" => Dict(
            "fastfoodrest" => 89.48929949,
            "fullservicerest" => 277.8184269,
            "hospital" => 790.9262388,
            "largehotel" => 7563.607619,
            "largeoffice" => 258.6874644,
            "mediumoffice" => 37.28641454,
            "midriseapartment" => 321.1473562,
            "outpatient" => 48.51884975,
            "primaryschool" => 191.9480118,
            "retailstore" => 0.0,
            "secondaryschool" => 491.5554097,
            "smallhotel" => 433.8738637,
            "smalloffice" => 11.42620649,
            "stripmall" => 0.0,
            "supermarket" => 25.53218144,
            "warehouse" => 0.0,
            "flatload" => 658.8635839
        ),
        "Helena" => Dict(
            "fastfoodrest" => 90.44011877,
            "fullservicerest" => 280.9757902,
            "hospital" => 800.0940058,
            "largehotel" => 7665.023574,
            "largeoffice" => 262.1461576,
            "mediumoffice" => 37.68905029,
            "midriseapartment" => 325.4421541,
            "outpatient" => 49.09222188,
            "primaryschool" => 193.4573283,
            "retailstore" => 0.0,
            "secondaryschool" => 494.7393735,
            "smallhotel" => 438.9398731,
            "smalloffice" => 11.46564268,
            "stripmall" => 0.0,
            "supermarket" => 25.72866824,
            "warehouse" => 0.0,
            "flatload" => 667.2021224
        ),
        "Duluth" => Dict(
            "fastfoodrest" => 98.10641517,
            "fullservicerest" => 306.4772907,
            "hospital" => 874.2611723,
            "largehotel" => 8484.906093,
            "largeoffice" => 290.0193773,
            "mediumoffice" => 40.92475821,
            "midriseapartment" => 360.161261,
            "outpatient" => 53.53681127,
            "primaryschool" => 211.2386551,
            "retailstore" => 0.0,
            "secondaryschool" => 543.3733772,
            "smallhotel" => 479.7414481,
            "smalloffice" => 11.79316054,
            "stripmall" => 0.0,
            "supermarket" => 27.3451629,
            "warehouse" => 0.0,
            "flatload" => 736.3678114
        ),
        "Fairbanks" => Dict(
            "fastfoodrest" => 108.5335945,
            "fullservicerest" => 341.1572799,
            "hospital" => 975.1062178,
            "largehotel" => 9600.267161,
            "largeoffice" => 327.8820873,
            "mediumoffice" => 45.32138512,
            "midriseapartment" => 407.3910855,
            "outpatient" => 59.6203514,
            "primaryschool" => 234.2595741,
            "retailstore" => 0.0,
            "secondaryschool" => 604.6838786,
            "smallhotel" => 535.2525234,
            "smalloffice" => 12.23744003,
            "stripmall" => 0.0,
            "supermarket" => 29.53958045,
            "warehouse" => 0.0,
            "flatload" => 830.07826
        )
    )
    if isempty(city)
        city = find_ashrae_zone_city(latitude, longitude)
    end
    if !(buildingtype in default_buildings)
        error("buildingtype $(buildingtype) not in $(default_buildings).")
    end
    if isnothing(annual_mmbtu)
        annual_mmbtu = dhw_annual_mmbtu[city][lowercase(buildingtype)]
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
    monthly_mmbtu::Union{<:Real, Vector{<:Real}}=nothing,
    )
    spaceheating_annual_mmbtu = Dict(
        "Miami" => Dict(
            "fastfoodrest" => 5.426780867,
            "fullservicerest" => 12.03181471,
            "hospital" => 6248.413294,
            "largehotel" => 198.0691407,
            "largeoffice" => 168.9731637,
            "mediumoffice" => 0.036985655,
            "midriseapartment" => 38.70606161,
            "outpatient" => 2559.185872,
            "primaryschool" => 49.78021153,
            "retailstore" => 12.12015432,
            "secondaryschool" => 203.5185485,
            "smallhotel" => 9.098564901,
            "smalloffice" => 0.312524873,
            "stripmall" => 20.73216748,
            "supermarket" => 101.2785324,
            "warehouse" => 56.0796017,
            "flatload" => 605.2352137
        ),
        "Houston" => Dict(
            "fastfoodrest" => 85.49111065,
            "fullservicerest" => 199.7942842,
            "hospital" => 8732.10385,
            "largehotel" => 1307.035548,
            "largeoffice" => 2229.971744,
            "mediumoffice" => 16.25994314,
            "midriseapartment" => 386.0269973,
            "outpatient" => 2829.324307,
            "primaryschool" => 469.2532935,
            "retailstore" => 289.0470815,
            "secondaryschool" => 2011.1678969999998,
            "smallhotel" => 108.9825885,
            "smalloffice" => 19.55157672,
            "stripmall" => 292.23235389999996,
            "supermarket" => 984.7374347000001,
            "warehouse" => 475.9377273,
            "flatload" => 1277.307359
        ),
        "Phoenix" => Dict(
            "fastfoodrest" => 57.89972381,
            "fullservicerest" => 147.2569493,
            "hospital" => 9382.021026,
            "largehotel" => 896.790817,
            "largeoffice" => 1584.061452,
            "mediumoffice" => 1.922551528,
            "midriseapartment" => 290.9887152,
            "outpatient" => 3076.340876,
            "primaryschool" => 305.573525,
            "retailstore" => 208.66330580000002,
            "secondaryschool" => 1400.638544,
            "smallhotel" => 83.98084516,
            "smalloffice" => 9.988210938,
            "stripmall" => 230.16060699999997,
            "supermarket" => 972.3008295,
            "warehouse" => 362.42249280000004,
            "flatload" => 1188.188154
        ),
        "Atlanta" => Dict(
            "fastfoodrest" => 168.8402371,
            "fullservicerest" => 379.5865464,
            "hospital" => 10467.659959999999,
            "largehotel" => 2427.6589879999997,
            "largeoffice" => 3624.593975,
            "mediumoffice" => 49.00635733,
            "midriseapartment" => 718.9316697,
            "outpatient" => 3186.250588,
            "primaryschool" => 931.7212450999999,
            "retailstore" => 627.2489826000001,
            "secondaryschool" => 3968.4936420000004,
            "smallhotel" => 202.26124219999997,
            "smalloffice" => 42.74797302,
            "stripmall" => 615.2240506,
            "supermarket" => 1880.5304489999999,
            "warehouse" => 930.9449202,
            "flatload" => 1888.856302
        ),
        "LasVegas" => Dict(
            "fastfoodrest" => 100.0877773,
            "fullservicerest" => 247.21791319999997,
            "hospital" => 9100.302056,
            "largehotel" => 1500.581408,
            "largeoffice" => 2479.152321,
            "mediumoffice" => 5.220181581,
            "midriseapartment" => 487.43122850000003,
            "outpatient" => 2924.8220460000002,
            "primaryschool" => 499.6562223,
            "retailstore" => 386.0185744,
            "secondaryschool" => 2277.7410649999997,
            "smallhotel" => 138.4427074,
            "smalloffice" => 19.16330622,
            "stripmall" => 389.30494280000005,
            "supermarket" => 1479.302604,
            "warehouse" => 579.7671637999999,
            "flatload" => 1413.3882199999998
        ),
        "LosAngeles" => Dict(
            "fastfoodrest" => 40.90390152,
            "fullservicerest" => 97.94277036,
            "hospital" => 10346.1713,
            "largehotel" => 707.848762,
            "largeoffice" => 1458.148818,
            "mediumoffice" => 0.12342009699999999,
            "midriseapartment" => 265.2851759,
            "outpatient" => 3417.120585,
            "primaryschool" => 318.73600980000003,
            "retailstore" => 175.104083,
            "secondaryschool" => 1198.276619,
            "smallhotel" => 72.42852638,
            "smalloffice" => 5.898878347,
            "stripmall" => 193.18730269999998,
            "supermarket" => 1040.273464,
            "warehouse" => 323.96697819999997,
            "flatload" => 1228.8385369999999
        ),
        "SanFrancisco" => Dict(
            "fastfoodrest" => 127.22328700000001,
            "fullservicerest" => 362.48645889999995,
            "hospital" => 11570.9155,
            "largehotel" => 1713.3629670000003,
            "largeoffice" => 2690.1191,
            "mediumoffice" => 3.8159670660000002,
            "midriseapartment" => 648.4472797999999,
            "outpatient" => 3299.0539519999998,
            "primaryschool" => 818.2159102,
            "retailstore" => 569.8081034,
            "secondaryschool" => 3414.148347,
            "smallhotel" => 189.0244446,
            "smalloffice" => 27.53039453,
            "stripmall" => 526.2320428,
            "supermarket" => 2301.616069,
            "warehouse" => 675.6758453,
            "flatload" => 1808.604729
        ),
        "Baltimore" => Dict(
            "fastfoodrest" => 305.2671204,
            "fullservicerest" => 657.1337578,
            "hospital" => 11253.61694,
            "largehotel" => 3731.0254619999996,
            "largeoffice" => 5109.311943,
            "mediumoffice" => 116.8101842,
            "midriseapartment" => 1132.964052,
            "outpatient" => 3285.227941,
            "primaryschool" => 1428.239177,
            "retailstore" => 1068.034778,
            "secondaryschool" => 6557.634924,
            "smallhotel" => 346.3683857,
            "smalloffice" => 63.29818348,
            "stripmall" => 1075.39546,
            "supermarket" => 2929.182261,
            "warehouse" => 1568.722061,
            "flatload" => 2539.2645399999997
        ),
        "Albuquerque" => Dict(
            "fastfoodrest" => 199.73581399999998,
            "fullservicerest" => 398.5712205,
            "hospital" => 8371.240776999999,
            "largehotel" => 2750.8382260000003,
            "largeoffice" => 3562.0023950000004,
            "mediumoffice" => 47.49307973,
            "midriseapartment" => 805.0965778,
            "outpatient" => 2971.868562,
            "primaryschool" => 981.4176700999999,
            "retailstore" => 755.4523907,
            "secondaryschool" => 4338.227865999999,
            "smallhotel" => 232.2194443,
            "smalloffice" => 43.25360481,
            "stripmall" => 760.0982018,
            "supermarket" => 2302.228741,
            "warehouse" => 1151.250885,
            "flatload" => 1854.437216
        ),
        "Seattle" => Dict(
            "fastfoodrest" => 255.5992711,
            "fullservicerest" => 627.5634984000001,
            "hospital" => 11935.157290000001,
            "largehotel" => 3343.683348,
            "largeoffice" => 5266.970348,
            "mediumoffice" => 28.97979768,
            "midriseapartment" => 1117.5465470000001,
            "outpatient" => 3468.128914,
            "primaryschool" => 1263.541878,
            "retailstore" => 952.2758742000001,
            "secondaryschool" => 6367.850187,
            "smallhotel" => 310.8087307,
            "smalloffice" => 49.34878545,
            "stripmall" => 969.1074739000001,
            "supermarket" => 3004.1844929999997,
            "warehouse" => 1137.398514,
            "flatload" => 2506.1340600000003
        ),
        "Chicago" => Dict(
            "fastfoodrest" => 441.93439000000006,
            "fullservicerest" => 888.3312571,
            "hospital" => 12329.57943,
            "largehotel" => 5104.848129,
            "largeoffice" => 7706.028917000001,
            "mediumoffice" => 216.01411800000002,
            "midriseapartment" => 1482.040156,
            "outpatient" => 3506.5381090000005,
            "primaryschool" => 2006.0002120000001,
            "retailstore" => 1472.8704380000001,
            "secondaryschool" => 8962.172873,
            "smallhotel" => 479.4653436000001,
            "smalloffice" => 94.19308949,
            "stripmall" => 1497.556168,
            "supermarket" => 3696.2112950000005,
            "warehouse" => 2256.477231,
            "flatload" => 3258.766323
        ),
        "Boulder" => Dict(
            "fastfoodrest" => 306.8980525,
            "fullservicerest" => 642.8843574,
            "hospital" => 9169.381845,
            "largehotel" => 3975.1080020000004,
            "largeoffice" => 5027.882454,
            "mediumoffice" => 124.26913059999998,
            "midriseapartment" => 1098.944993,
            "outpatient" => 3087.969786,
            "primaryschool" => 1356.396807,
            "retailstore" => 1086.9187570000001,
            "secondaryschool" => 6268.036872,
            "smallhotel" => 342.77800099999996,
            "smalloffice" => 65.95714912,
            "stripmall" => 1093.093638,
            "supermarket" => 2966.790122,
            "warehouse" => 1704.8648210000001,
            "flatload" => 2394.8859239999997
        ),
        "Minneapolis" => Dict(
            "fastfoodrest" => 588.8854722,
            "fullservicerest" => 1121.229499,
            "hospital" => 13031.2313,
            "largehotel" => 6359.946704,
            "largeoffice" => 10199.279129999999,
            "mediumoffice" => 394.1525556,
            "midriseapartment" => 1814.148381,
            "outpatient" => 3661.1462229999997,
            "primaryschool" => 2600.964302,
            "retailstore" => 1869.8106289999998,
            "secondaryschool" => 11963.323859999999,
            "smallhotel" => 618.0427338999999,
            "smalloffice" => 128.12525349999999,
            "stripmall" => 1952.731917,
            "supermarket" => 4529.776664,
            "warehouse" => 3231.223746,
            "flatload" => 4004.001148
        ),
        "Helena" => Dict(
            "fastfoodrest" => 468.8276835,
            "fullservicerest" => 934.8994934,
            "hospital" => 10760.57411,
            "largehotel" => 5554.910785,
            "largeoffice" => 7373.056709,
            "mediumoffice" => 239.8330306,
            "midriseapartment" => 1531.102079,
            "outpatient" => 3390.42972,
            "primaryschool" => 2097.777112,
            "retailstore" => 1494.85988,
            "secondaryschool" => 9535.484059,
            "smallhotel" => 499.85992930000003,
            "smalloffice" => 98.85818175,
            "stripmall" => 1604.0043970000002,
            "supermarket" => 3948.5338049999996,
            "warehouse" => 2504.784991,
            "flatload" => 3252.362248
        ),
        "Duluth" => Dict(
            "fastfoodrest" => 738.1353594999999,
            "fullservicerest" => 1400.36692,
            "hospital" => 14179.84149,
            "largehotel" => 7781.9012760000005,
            "largeoffice" => 12504.64187,
            "mediumoffice" => 468.2112216,
            "midriseapartment" => 2204.85149,
            "outpatient" => 3774.3233130000003,
            "primaryschool" => 3160.1200719999997,
            "retailstore" => 2298.8242920000002,
            "secondaryschool" => 14468.64346,
            "smallhotel" => 772.5386662000001,
            "smalloffice" => 155.8350887,
            "stripmall" => 2411.847491,
            "supermarket" => 5587.977185,
            "warehouse" => 3962.122014,
            "flatload" => 4741.886326
        ),
        "Fairbanks" => Dict(
            "fastfoodrest" => 1245.3608279999999,
            "fullservicerest" => 2209.293209,
            "hospital" => 20759.042680000002,
            "largehotel" => 12298.7791,
            "largeoffice" => 23214.51532,
            "mediumoffice" => 949.8812392000001,
            "midriseapartment" => 3398.039504,
            "outpatient" => 4824.076322999999,
            "primaryschool" => 6341.861225,
            "retailstore" => 3869.670979,
            "secondaryschool" => 25619.149269999998,
            "smallhotel" => 1264.41064,
            "smalloffice" => 297.08593010000004,
            "stripmall" => 3934.89178,
            "supermarket" => 8515.422039000001,
            "warehouse" => 6882.6512680000005,
            "flatload" => 7851.508208
        )
    )
    if isempty(city)
        city = find_ashrae_zone_city(latitude, longitude)
    end
    if !(buildingtype in default_buildings)
        error("buildingtype $(buildingtype) not in $(default_buildings).")
    end
    if isnothing(annual_mmbtu)
        annual_mmbtu = spaceheating_annual_mmbtu[city][lowercase(buildingtype)]
    end
    built_in_load("space_heating", city, buildingtype, year, annual_mmbtu, monthly_mmbtu)
end