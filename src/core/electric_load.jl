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
"""
    ElectricLoad(;
        loads_kw::Union{Missing, Array{<:Real,1}} = missing,
        year::Int = 2020,
        doe_reference_name::Union{Missing, String} = missing,
        city::Union{Missing, String} = missing,
        annual_kwh::Union{Real, Nothing} = nothing,
        monthly_totals_kwh::Array{<:Real,1} = Real[],
        critical_loads_kw::Union{Missing, Array{Real,1}} = missing,
        loads_kw_is_net::Bool = true,
        critical_loads_kw_is_net::Bool = false,
        critical_load_pct::Real = 0.5
    )

Must provide either `loads_kw` or [`doe_reference_name` and `city`]. When using the 
[`doe_reference_name` and `city`] option, choose `city` from one of the 
cities used to represent the ASHRAE climate zones:
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
- FlatLoad

Each `city` and `doe_reference_name` combination has a default `annual_kwh`, or you can provide your
own `annual_kwh` or `monthly_totals_kwh` and the reference profile will be scaled appropriately.
"""
mutable struct ElectricLoad  # mutable to adjust (critical_)loads_kw based off of (critical_)loads_kw_is_net
    loads_kw::Array{Real,1}
    year::Int
    critical_loads_kw::Array{Real,1}
    loads_kw_is_net::Bool
    critical_loads_kw_is_net::Bool
    
    function ElectricLoad(;
        loads_kw::Union{Missing, Array{<:Real,1}} = missing,
        year::Int = 2020,
        doe_reference_name::Union{Missing, String} = missing,
        city::String = "",
        annual_kwh::Union{Real, Nothing} = nothing,
        monthly_totals_kwh::Array{<:Real,1} = Real[],
        critical_loads_kw::Union{Missing, Array{Real,1}} = missing,
        loads_kw_is_net::Bool = true,
        critical_loads_kw_is_net::Bool = false,
        critical_load_pct::Real = 0.5,
        latitude::Float64,
        longitude::Float64
        )
        
        if !ismissing(loads_kw)
            if ismissing(critical_loads_kw)
                critical_loads_kw = critical_load_pct * loads_kw
            end
            return new(
                loads_kw,
                year,
                critical_loads_kw,
                loads_kw_is_net,
                critical_loads_kw_is_net
            )     
    
        elseif !ismissing(doe_reference_name)
            # NOTE: must use year that starts on Sunday with DOE reference doe_ref_profiles
            if year != 2017
                @warn "Changing ElectricLoad.year to 2017 because DOE reference profiles start on a Sunday."
            end
            year = 2017
            loads_kw = BuiltInElectricLoad(city, doe_reference_name, latitude, longitude, annual_kwh=annual_kwh)
            if ismissing(critical_loads_kw)
                critical_loads_kw = critical_load_pct * loads_kw
            end
            return new(
                loads_kw,
                year,
                critical_loads_kw,
                loads_kw_is_net,
                critical_loads_kw_is_net
            )
            
        else
            error("Cannot construct ElectricLoad. You must provide either loads_kw, [doe_reference_name, city], 
                  or [doe_reference_name, latitude, longitude].")
        end
    end
end


function BuiltInElectricLoad(
    city::String,
    buildingtype::String,
    latitude::Float64,
    longitude::Float64;
    annual_kwh::Union{Float64,Nothing}=nothing
    )
    lib_path = joinpath(dirname(@__FILE__), "..", "..", "data")
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
    default_buildings = [
        "FastFoodRest",
        "FullServiceRest",
        "Hospital",
        "LargeHotel",
        "LargeOffice",
        "MediumOffice",
        "MidriseApartment",
        "Outpatient",
        "PrimarySchool",
        "RetailStore",
        "SecondarySchool",
        "SmallHotel",
        "SmallOffice",
        "StripMall",
        "Supermarket",
        "Warehouse",
        "FlatLoad",
    ]
    if !(buildingtype in default_buildings)
        error("buildingtype $(buildingtype) not in $(default_buildings).")
    end

    if isnothing(annual_kwh)
        annual_kwh = annual_loads[city][lowercase(buildingtype)]
    end
     # TODO implement BuiltInElectricLoad scaling based on monthly_totals_kwh

    if isempty(city)
        city = find_ashrae_zone_city(latitude, longitude)
    end
    profile_path = joinpath(lib_path, string("Load8760_norm_" * city * "_" * buildingtype * ".dat"))
    normalized_profile = vec(readdlm(profile_path, '\n', Float64, '\n'))

    load = [annual_kwh * ld for ld in normalized_profile]
end


function find_ashrae_zone_city(lat, lon)::String
    file_path = joinpath(dirname(@__FILE__), "..", "..", "data", "climate_cities.shp")
    table = Shapefile.Table(file_path)
    geoms = Shapefile.shapes(table)
    # TODO following for loop is relatively slow
    for (row, geo) in enumerate(geoms)
        g = length(geo.points)
        nodes = zeros(g, 2)
        edges = zeros(g, 2)
        for (i,p) in enumerate(geo.points)
            nodes[i,:] = [p.x, p.y]
            edges[i,:] = [i, i+1]
        end
        edges[g, :] = [g, 1]
        edges = convert(Array{Int64,2}, edges)
        # shapefiles have longitude as x, latitude as y  
        if inpoly2([lon, lat], nodes, edges)[1]
            return table.city[row]
        end
        GC.gc()
    end
    @info "Could not find latitude/longitude in U.S. Using geometrically nearest city."
    cities = [
        (city="Miami", lat=25.761680, lon=-80.191790),
        (city="Houston", lat=29.760427, lon=-95.369803),
        (city="Phoenix", lat=33.448377, lon=-112.074037),
        (city="Atlanta", lat=33.748995, lon=-84.387982),
        (city="LasVegas", lat=36.1699, lon=-115.1398),
        (city="LosAngeles", lat=34.052234, lon=-118.243685),
        (city="SanFrancisco", lat=37.3382, lon=-121.8863),
        (city="Baltimore", lat=39.290385, lon=-76.612189),
        (city="Albuquerque", lat=35.085334, lon=-106.605553),
        (city="Seattle", lat=47.606209, lon=-122.332071),
        (city="Chicago", lat=41.878114, lon=-87.629798),
        (city="Boulder", lat=40.014986, lon=-105.270546),
        (city="Minneapolis", lat=44.977753, lon=-93.265011),
        (city="Helena", lat=46.588371, lon=-112.024505,),
        (city="Duluth", lat=46.786672, lon=-92.100485),
        (city="Fairbanks", lat=59.0397, lon=-158.4575),
    ]
    min_distance = 0.0
    nearest_city = ""
    for (i, c) in enumerate(cities)
        distance = sqrt((lat - c.lat)^2 + (lon - c.lon)^2)
        if i == 1
            min_distance = distance
            nearest_city = c.city
        elseif distance < min_distance
            min_distance = distance
            nearest_city = c.city
        end
    end
    return nearest_city
end
