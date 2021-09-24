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
const default_buildings = [
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

const MMBTU_TO_KWH = 293.07107


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


"""
    built_in_load(type::String, city::String, buildingtype::String, 
        year::Int, annual_energy::Real, monthly_energies::AbstractArray{Real,1}
    )
Scale a normalized Commercial Reference Building according to inputs provided and return the 8760.
"""
function built_in_load(type::String, city::String, buildingtype::String, 
    year::Int, annual_energy::Real, monthly_energies::AbstractArray{Real,1}
    )

    @assert type in ["electric", "domestic_hot_water", "space_heating"]
    monthly_scalers = ones(12)
    lib_path = joinpath(dirname(@__FILE__), "..", "..", "data", "load_profiles", type)

    profile_path = joinpath(lib_path, string("crb8760_norm_" * city * "_" * buildingtype * ".dat"))
    normalized_profile = vec(readdlm(profile_path, '\n', Float64, '\n'))
    
    if length(monthly_energies) == 12
        annual_energy = 1.0  # do not scale based on annual_energy
        t0 = 1
        for month in 1:12
            plus_hours = daysinmonth(Date(string(year) * "-" * string(month))) * 24
            if month == 2 && isleapyear(year)
                plus_hours -= 24
            end
            month_total = sum(normalized_profile[t0:t0+plus_hours-1])
            if month_total == 0.0  # avoid division by zero
                monthly_scalers[month] = 0.0
            else
                monthly_scalers[month] = monthly_energies[month] / month_total
            end
            t0 += plus_hours
        end
    end

    scaled_load = Float64[]
    boiler_efficiency = 1.0
    mmbtu_to_kwh = 1.0  # do not convert electric loads
    if type in ["domestic_hot_water", "space_heating"]
        # CRB thermal "loads" are in terms of energy input required (boiler fuel), not the actual energy demand.
        # So we multiply the fuel energy by the boiler_efficiency to get the actual energy demand.
        boiler_efficiency = EXISTING_BOILER_EFFICIENCY
        mmbtu_to_kwh = MMBTU_TO_KWH  # do convert thermal loads
    end
    datetime = DateTime(year, 1, 1, 1)
    for ld in normalized_profile
        month = Month(datetime).value
        push!(scaled_load, ld * annual_energy * monthly_scalers[month] * boiler_efficiency * mmbtu_to_kwh)
        datetime += Dates.Hour(1)
    end

    return scaled_load
end


"""
    blend_and_scale_doe_profiles(
        constructor,
        latitude::Float64,
        longitude::Float64,
        year::Int,
        blended_doe_reference_names::Array{String, 1},
        blended_doe_reference_percents::Array{<:Real,1},
        city::String = "",
        annual_energy::Union{Real, Nothing} = nothing,
        monthly_energies::Array{<:Real,1} = Real[],
    )

Given `blended_doe_reference_names` and `blended_doe_reference_percents` use the `constructor` function to load in DoE 
    CRB profiles and create a single profile, where `constructor` is one of:
    - BuiltInElectricLoad
    - BuiltInDomesticHotWaterLoad
    - BuiltInSpaceHeatingLoad
"""
function blend_and_scale_doe_profiles(
    constructor,
    latitude::Float64,
    longitude::Float64,
    year::Int,
    blended_doe_reference_names::Array{String, 1},
    blended_doe_reference_percents::Array{<:Real,1},
    city::String = "",
    annual_energy::Union{Real, Nothing} = nothing,
    monthly_energies::Array{<:Real,1} = Real[],
    )

    @assert sum(blended_doe_reference_percents) ≈ 1 "The sum of the blended_doe_reference_percents must equal 1"
    if year != 2017
        @warn "Changing ElectricLoad.year to 2017 because DOE reference profiles start on a Sunday."
    end
    year = 2017
    if isempty(city)
        city = find_ashrae_zone_city(latitude, longitude)  # avoid redundant look-ups
    end
    profiles = Array[]  # collect the built in profiles
    for name in blended_doe_reference_names
        push!(profiles, constructor(city, name, latitude, longitude, year, annual_energy, monthly_energies))
    end
    if isnothing(annual_energy) # then annual_energy should be the sum of all the profiles' annual kwhs
        # we have to rescale the built in profiles to the total_kwh by normalizing them with their
        # own annual kwh and multiplying by the total kwh
        annual_kwhs = [sum(profile) for profile in profiles]
        total_kwh = sum(annual_kwhs)
        monthly_scaler = 1
        if length(monthly_energies) == 12
            monthly_scaler = length(blended_doe_reference_names)
        end
        for idx in 1:length(profiles)
            profiles[idx] .*= total_kwh / annual_kwhs[idx] / monthly_scaler
        end
    end
    for idx in 1:length(profiles)  # scale the profiles
        profiles[idx] .*= blended_doe_reference_percents[idx]
    end
    sum(profiles)
end