# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met
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
    transition_prob(n::Vector{Int}, n_prime::Vector{Int}, p::Real)

Return the probability of going from i to j generators given a failure rate of ``p`` for each i,j pair in vectors ``n`` and ``n_prime``.

Function used to create transition probabilities in Markov matrix.

# Examples
```repl-julia
julia> transition_prob([1,2,3,4], [0,1,2,3], 0.5)
4-element Vector{Float64}:
 0.5
 0.5
 0.375
 0.25
```
"""
function transition_prob(n::Vector{Int}, n_prime::Vector{Int}, p::Real)::Vector{Float64} 
    return binomial.(n, n_prime).*(1-p).^(n_prime).*(p).^(n-n_prime)
end

"""
    markov_matrix(N::Int, p::Real)

Return an ``N``+1 by ``N``+1 matrix of transition probabilities of going from n (row) to n' (column) given probability ``p``

Row n denotes starting with n-1 generators, with the first row denoting zero working generators. Column n' denots ending with n'-1 generators.

# Examples
```repl-julia
julia> markov_matrix(2, 0.1)
3×3 Matrix{Float64}:
 1.0   0.0   0.0
 0.1   0.9   0.0
 0.01  0.18  0.81
```
"""
function markov_matrix(N::Int, p::Real)::Matrix{Float64} 
    #Creates Markov matrix for generator transition probabilities
    M = reshape(transition_prob(repeat(0:N, outer = N + 1), repeat(0:N, inner = N+1), p), N+1, N+1)
    replace!(M, NaN => 0)
    return M
end

"""
    starting_probabilities(N::Int, OA::Numberic, failure_to_start::Real)

Return a 1 by ``N``+1 by matrix (row vector) of probabilities of number of generators operationally available (``OA``) and avoiding
a Failure to Start (``failure_to_start``)

The first element denotes no generators successfully starts and element n denotes n-1 generators start

# Arguments
- `N::Int`: the number of generators 
- `OA::Real`: Operational Availability. The chance that a generator will be available (not down for maintenance) at the start of the outage
- `failure_to_start::Real`: Failure to Start. The chance that a generator fails to successfully start and take load.

# Examples
```repl-julia
julia> starting_probabilities(2, 0.99, 0.05)
1×3 Matrix{Float64}:
 0.00354025  0.11192  0.88454
```
"""
function starting_probabilities(N::Int, OA::Real, failure_to_start::Real)::Matrix{Float64} 
    M = markov_matrix(N, (1-OA) + failure_to_start*OA) 
    G = hcat(zeros(1, N), 1)
    return G * M
end

"""
    bin_battery_charge(batt_soc_kwh::Vector, num_bins::Int, batt_kwh::Real)

Return a vector equal to the length of ``batt_soc_kwh`` of discritized battery charge bins

The first bin denotes zero battery charge, and each additional bin has size of ``batt_kwh``/(``num_bins``-1)
Values are rounded to nearest bin.

# Examples
```repl-julia
julia>  bin_batt_soc_kwh([30, 100, 170.5, 250, 251, 1000], 11, 1000)
6-element Vector{Int64}:
  1
  2
  3
  3
  4
 11
```
"""
function bin_battery_charge(batt_soc_kwh::Vector, num_bins::Int, batt_kwh::Real)::Vector{Int}  
    #Bins battery into discrete portions. Zero is one of the bins. 
    bin_size = batt_kwh / (num_bins-1)
    return min.(num_bins, round.(batt_soc_kwh./bin_size).+1)
end

"""
    generator_output(num_generators::Int, gen_capacity::Real)

Return a vector equal to the length of ``num_generators``+1 of mazimized generator capacity given 0 to ``num_generators`` are available
"""
function generator_output(num_generators::Int, gen_capacity::Real)::Vector{Float64} 
    #Returns vector of maximum generator output
    return collect(0:num_generators).*gen_capacity
end

"""
    get_maximum_generation(batt_kw::Real, gen_capacity::Real, bin_size::Real, 
                           num_bins::Int, num_generators::Int, batt_discharge_efficiency::Real)

Return a matrix of maximum total system output.

Rows denote battery state of charge bin and columns denote number of available generators, with the first column denoting zero available generators.

# Arguments
- `batt_kw::Real`: battery inverter size
- `gen_capacity::Real`: maximum output from single generator. 
- `bin_size::Real`: size of discretized battery soc bin. is equal to batt_kwh / (num_bins - 1) 
- `num_bins::Int`: number of battery bins. 
- `num_generators::Int`: number of generators in microgrid.
- `batt_discharge_efficiency::Real`: batt_discharge_efficiency = battery_discharge / battery_reduction_in_soc

# Examples
```repl-julia
julia>  get_maximum_generation(1000, 750, 250, 5, 3, 1.0)
5×4 Matrix{Float64}:
    0.0   750.0  1500.0  2250.0
  250.0  1000.0  1750.0  2500.0
  500.0  1250.0  2000.0  2750.0
  750.0  1500.0  2250.0  3000.0
 1000.0  1750.0  2500.0  3250.0
```
"""
function get_maximum_generation(batt_kw::Real, gen_capacity::Real, bin_size::Real, 
                   num_bins::Int, num_generators::Int, batt_discharge_efficiency::Real)::Matrix{Float64}
    #Returns a matrix of maximum hourly generation (rows denote number of generators starting at 0, columns denote battery bin)
    N = num_generators + 1
    M = num_bins
    max_battery_discharge = zeros(M, N) 
    generator_prod = zeros(M, N)
    for i in 1:M
       max_battery_discharge[i, :] = fill(min(batt_kw, (i-1)*bin_size*batt_discharge_efficiency), N)
       generator_prod[i, :] = generator_output(num_generators, gen_capacity)
    end
    
    return generator_prod .+ max_battery_discharge
end

"""
    battery_bin_shift(excess_generation::Vector, bin_size::Real, batt_kw::Real, batt_charge_efficiency::Real, batt_discharge_efficiency::Real)

Return a vector of number of bins battery is shifted by

# Arguments
- `excess_generation::Vector`: maximum generator output minus net critical load for each number of working generators
- `bin_size::Real`: size of battery bin
- `batt_kw::Real`: inverter size
- `batt_charge_efficiency::Real`: batt_charge_efficiency = increase_in_soc_kwh / grid_input_kwh 
- `batt_discharge_efficiency::Real`: batt_discharge_efficiency = battery_discharge / battery_reduction_in_soc

"""
function battery_bin_shift(excess_generation::Vector, bin_size::Real, batt_kw::Real,
                                batt_charge_efficiency::Real, batt_discharge_efficiency::Real)::Vector{Int} 
    #Determines how many battery bins to shift by
    #Lose energy charging battery and use more energy discharging battery
    #Need to shift battery up by less and down by more.
    
    #positive excess generation 
    excess_generation[excess_generation .> 0] = excess_generation[excess_generation .> 0] .* batt_charge_efficiency
    excess_generation[excess_generation .< 0] = excess_generation[excess_generation .< 0] ./ batt_discharge_efficiency
    #Battery cannot charge or discharge more than its capacity
    excess_generation[excess_generation .> batt_kw] .= batt_kw
    excess_generation[excess_generation .< -batt_kw] .= -batt_kw
    shift = round.(excess_generation ./ bin_size)
    # shift[is.nan(shift)] = 0
    return shift
end

"""
    shift_gen_battery_prob_matrix!(gen_battery_prob_matrix::Matrix, shift_vector::Vector{Int})

Updates ``gen_battery_prob_matrix`` in place to account for change in battery state of charge bin

shifts probabiilities in column i by ``shift_vector``[i] positions, accounting for accumulation at 0 or full soc   
"""
function shift_gen_battery_prob_matrix!(gen_battery_prob_matrix::Matrix, shift_vector::Vector{Int})
    M = size(gen_battery_prob_matrix, 1)

    for i in 1:length(shift_vector) 
        s = shift_vector[i]
        if s < 0 
            gen_battery_prob_matrix[:, i] = circshift(view(gen_battery_prob_matrix, :, i), s)
            gen_battery_prob_matrix[1, i] += sum(view(gen_battery_prob_matrix, max(2,M+s):M, i))
            gen_battery_prob_matrix[max(2,M+s):M, i] .= 0
        elseif s > 0
            gen_battery_prob_matrix[:, i] = circshift(view(gen_battery_prob_matrix, :, i), s)
            gen_battery_prob_matrix[end, i] += sum(view(gen_battery_prob_matrix, 1:min(s,M-1), i))
            gen_battery_prob_matrix[1:min(s,M-1), i] .= 0
        end
    end
end

"""
    survival_over_time_gen_only(critical_load::Vector, OA::Real, failure_to_start::Real, failure_to_run::Real, num_generators::Int,
                                gen_capacity::Real, max_duration::Int; marginal_survival = true)::Matrix{Float64}

Return a matrix of probability of survival with rows denoting outage start and columns denoting outage duration

Solves for probability of survival given only backup generators (no battery backup). 
If ``marginal_survival`` = true then result is chance of surviving in given outage hour, 
if ``marginal_survival`` = false then result is chance of surviving up to and including given outage hour.

# Arguments
- `critical_load::Vector`: 8760 vector of system critical loads. 
- `OA::Real`: Operational Availability of backup generators.
- `failure_to_start::Real`: probability of generator Failure to Start and support load. 
- `failure_to_run::Real`: hourly Failure to Run probability. failure_to_run is 1/MTTF (mean time to failure). 
- `num_generators::Int`: number of generators in microgrid.
- `gen_capacity::Real`: size of generator.
- `max_duration::Int`: maximum outage duration in hours.
- `marginal_survival::Bool`: indicates whether results are probability of survival in given outage hour or probability of surviving up to and including hour.

# Examples
Given failure_to_run = 0.2, the chance of no generators failing in 0.64 in hour 1, 0.4096 in hour 2, and 0.262144 in hour 3
Chance of 2 generators failing is 0.04 in hour 1, 0.1296 by hour 1, and 0.238144 by hour 3   
```repl-julia
julia> critical_load = [1,2,1,1]; OA = 1; failure_to_start = 0.0; failure_to_run = 0.2; num_generators = 2; gen_capacity = 1; max_duration = 3;

julia> survival_over_time_gen_only(critical_load, OA, failure_to_start, failure_to_run, num_generators, gen_capacity, max_duration; marginal_survival = true)
4×3 Matrix{Float64}:
 0.96  0.4096  0.761856
 0.64  0.8704  0.761856
 0.96  0.8704  0.761856
 0.96  0.8704  0.262144

julia> survival_over_time_gen_only(critical_load, OA, failure_to_start, failure_to_run, num_generators, gen_capacity, max_duration; marginal_survival = false)
4×3 Matrix{Float64}:
 0.96  0.4096  0.393216
 0.64  0.6144  0.557056
 0.96  0.8704  0.761856
 0.96  0.8704  0.262144
```
"""
                     
function survival_over_time_gen_only(critical_load::Vector, OA::Real, failure_to_start::Real, failure_to_run::Real, num_generators::Int, 
    gen_capacity::Real, max_duration::Int; marginal_survival = true)::Matrix{Float64} 

    t_max = length(critical_load)
    #
    generator_production = collect(0:num_generators).*gen_capacity
    #Initialize lost load matrix
    survival_probability_matrix = zeros(t_max, max_duration)
    #initialize amount of extra generation for each critical load hour and each amount of generators
    generator_markov_matrix = markov_matrix(num_generators, failure_to_run)
  
    #Get starting generator vector
    starting_gens = starting_probabilities(num_generators, OA, failure_to_start) #initialize gen battery prob matrix

    #start loop
    for t  = 1:t_max
        gen_probs = starting_gens
        #
        for d in 1:max_duration
            survival = ones(1, length(generator_production))
            
            h = mod(t + d - 2, t_max) + 1 #determines index accounting for looping around year
            net_gen = generator_production .- critical_load[h]
            survival[net_gen .< 0] .= 0

            gen_probs *= generator_markov_matrix #Update to account for generator failures
            survival_val = gen_probs .* survival
            
            if marginal_survival == false
                gen_probs = gen_probs .* survival
            end
            
            #update expected lost load for given outage start time and outage duration
            survival_probability_matrix[t, d] = sum(survival_val)
            #Update generation battery probability matrix to account for battery shifting
        end
    end
    return survival_probability_matrix
end

"""
    survival_with_battery(net_critical_load::Vector, starting_batt_soc_kwh::Vector, OA::Real, failure_to_start::Real, failure_to_run::Real, num_generators::Int,
                          gen_capacity::Real, batt_kwh::Real, batt_kw::Real, num_bins::Int, max_outage_duration::Int, 
                          batt_charge_efficiency::Real, batt_discharge_efficiency::Real; marginal_survival = true)::Matrix{Float64} 

Return a matrix of probability of survival with rows denoting outage start and columns denoting outage duration

Solves for probability of survival given both networked generators and battery backup. 
If ``marginal_survival`` = true then result is chance of surviving in given outage hour, 
if ``marginal_survival`` = false then result is chance of surviving up to and including given outage hour.

# Arguments
- `net_critical_load::Vector`: 8760 vector of system critical loads minus solar generation.
- `starting_batt_soc_kwh::Vector`: 8760 vector of battery charge (kwh) for each hour of year. 
- `OA::Real`: Operational Availability of backup generators.
- `failure_to_start::Real`: probability of generator Failure to Start and support load. 
- `failure_to_run::Real`: hourly Failure to Run probability. failure_to_run is 1/MTTF (mean time to failure). 
- `num_generators::Int`: number of generators in microgrid.
- `gen_capacity::Real`: size of generator.
- `batt_kwh::Real`: energy capacity of battery system.
- `batt_kw::Real`: battery system inverter size.
- `num_bins::Int`: number of battery bins. 
- `max_outage_duration::Int`: maximum outage duration in hours.
- `batt_charge_efficiency::Real`: batt_charge_efficiency = increase_in_soc_kwh / grid_input_kwh 
- `batt_discharge_efficiency::Real`: batt_discharge_efficiency = battery_discharge / battery_reduction_in_soc
- `marginal_survival::Bool`: indicates whether results are probability of survival in given outage hour or probability of surviving up to and including hour.

# Examples
Given failure_to_run = 0.2, the chance of no generators failing in 0.64 in hour 1, 0.4096 in hour 2, and 0.262144 in hour 3
Chance of 2 generators failing is 0.04 in hour 1, 0.1296 by hour 1, and 0.238144 by hour 3   
```repl-julia
julia> net_critical_load = [1,2,2,1]; starting_batt_soc_kwh = [1,1,1,1];  max_outage_duration = 3;
julia> num_generators = 2; gen_capacity = 1; OA = 1; failure_to_start = 0.0; failure_to_run = 0.2;
julia> num_bins = 3; batt_kwh = 2; batt_kw = 1;  batt_charge_efficiency = 1; batt_discharge_efficiency = 1;

julia> survival_with_battery(net_critical_load, starting_batt_soc_kwh, OA, failure_to_start, failure_to_run, num_generators, gen_capacity, batt_kwh, 
       batt_kw, num_bins, max_outage_duration, batt_charge_efficiency, batt_discharge_efficiency; marginal_survival = true)
4×3 Matrix{Float64}:
1.0   0.8704  0.393216
0.96  0.6144  0.77824
0.96  0.896   0.8192
1.0   0.96    0.761856

julia> survival_with_battery(net_critical_load, starting_batt_soc_kwh, OA, failure_to_start, failure_to_run, num_generators, gen_capacity, batt_kwh, 
       batt_kw, num_bins, max_outage_duration, batt_charge_efficiency, batt_discharge_efficiency; marginal_survival = false)
4×3 Matrix{Float64}:
1.0   0.8704  0.393216
0.96  0.6144  0.57344
0.96  0.896   0.8192
1.0   0.96    0.761856
```
"""
function survival_with_battery(net_critical_load::Vector, starting_batt_soc_kwh::Vector, OA::Real, failure_to_start::Real, failure_to_run::Real, num_generators::Int,
                               gen_capacity::Real, batt_kwh::Real, batt_kw::Real, num_bins::Int, max_outage_duration::Int, batt_charge_efficiency::Real,
                               batt_discharge_efficiency::Real; marginal_survival = true)::Matrix{Float64} 

    t_max = length(net_critical_load)
    
    #bin size is battery storage divided by num bins-1 because zero is also a bin
    bin_size = batt_kwh / (num_bins-1)
     
    #bin initial battery 
    starting_battery_bins = bin_battery_charge(starting_batt_soc_kwh, num_bins, batt_kwh) 
    #For easier indice reading
    M = num_bins
    N = num_generators + 1
    #Initialize lost load matrix
    survival_probability_matrix = zeros(t_max, max_outage_duration) 
    #initialize vectors and matrices
    generator_markov_matrix = markov_matrix(num_generators, failure_to_run) 
    gen_prod = generator_output(num_generators, gen_capacity)
    maximum_generation = get_maximum_generation(batt_kw, gen_capacity, bin_size, num_bins, num_generators, batt_discharge_efficiency)
    starting_gens = starting_probabilities(num_generators, OA, failure_to_start) 

    #loop through outage time
    tme = time()
    for t = 1:t_max
        gen_battery_prob_matrix = zeros(M, N)
        gen_battery_prob_matrix[starting_battery_bins[t], :] = starting_gens
        
        #loop through outage duration
        for d in 1:max_outage_duration 
            survival = ones(M, N)
            h = mod(t + d - 2, t_max) + 1 #determines index accounting for looping around year
            
            excess_generation = gen_prod .- net_critical_load[h]
            max_net_generation = maximum_generation .- net_critical_load[h]

            #System fails if net generation is always negative (cannot meet load)
            survival[max_net_generation .< 0, ] .= 0

            #Update probabilities to account for generator failures
            # time_vals["generator_shift"] += @elapsed account_for_generator_failures!(gen_battery_prob_matrix, generator_markov_matrix)
            gen_battery_prob_matrix *= generator_markov_matrix 
            # account_for_generator_failures!(gen_battery_prob_matrix, generator_markov_matrix)

            #Update survival probabilities
            survival_chance = gen_battery_prob_matrix .* survival

            #If marginal survival is false then remove probabilities which did not meet load
            if marginal_survival == false
                gen_battery_prob_matrix = gen_battery_prob_matrix .* survival
            end
            #update expected lost load for given outage start time and outage duration
            survival_probability_matrix[t, d] = sum(survival_chance)
            #Update generation battery probability matrix to account for battery shifting
            shift_gen_battery_prob_matrix!(gen_battery_prob_matrix, battery_bin_shift(excess_generation, bin_size, batt_kw, batt_charge_efficiency, batt_discharge_efficiency))
        end
    end
    return survival_probability_matrix
end

"""
    backup_reliability_inputs(d::Dict, p::REoptInputs; r::Dict)::Dict

Return a dictionary of inputs required for backup reliability calculations. 

# Arguments
- `d::Dict`: REopt results dictionary. 
- `r::Dict`: Dictionary of inputs for reliability calculations. If r not included then uses all defaults. values read from dictionary:
    -gen_operational_availability::Real = 0.9998        Fraction of year generators not down for maintenance
    -gen_failure_to_start::Real = 0.0066                Chance of generator starting given outage
    -gen_failure_to_run::Real = 0.00157                 Chance of generator failing in each hour of outage
    -num_gens::Int = 1                                  Number of generators. Will be determined by code if set to 0 and gen capacity > 0.1
    -gen_capacity::Real = 0.0                           Backup generator capacity. Will be determined by REopt optimization if set less than 0.1
    -num_battery_bins::Int = 100                        Internal value for modeling battery
    -max_outage_duration::Int = 96                      Maximum outage hour modeled
    -microgrid_only::Bool = false                       Determines how generator, PV, and battery act during islanded mode
```
"""
function backup_reliability_inputs(d::Dict, p::REoptInputs; r::Dict = Dict())::Dict
    zero_array = zeros(length(p.time_steps))
    r2 = dictkeys_tosymbols(r)
    critical_loads_kw = p.s.electric_load.critical_loads_kw

    if "CHP" in keys(d)
        chp_generation =  get(d["CHP"], "electric_production_series_kw", zero_array)
        critical_loads_kw .-= chp_generation
    end

    microgrid_only = get(r, "microgrid_only", false)

    pv_kw_ac_hourly = zero_array
    if "PV" in keys(d)
        pv_kw_ac_hourly = (
            get(d["PV"], "electric_to_storage_series_kw", zero_array)
            + get(d["PV"], "electric_curtailed_series_kw", zero_array)
            + get(d["PV"], "electric_to_load_series_kw", zero_array)
            + get(d["PV"], "electric_to_grid_series_kw", zero_array)
        )
    end
    if microgrid_only && !Bool(get(d, "PV_upgraded", false))
        pv_kw_ac_hourly = zero_array
    end

    batt_kwh = 0
    batt_kw = 0
    if "Storage" in keys(d)
        #TODO change to throw error if multiple storage types
        for b in p.s.storage.types.elec
            batt_charge_efficiency = p.s.storage.attr[b].charge_efficiency
            batt_discharge_efficiency = p.s.storage.attr[b].discharge_efficiency
        end
            
        batt_kwh = get(d["Storage"], "size_kwh", 0)
        batt_kw = get(d["Storage"], "size_kw", 0)
        init_soc = get(d["Storage"], "soc_series_fraction", [])

        if microgrid_only && !Bool(get(d, "storage_upgraded", false))
            batt_kwh = 0
            batt_kw = 0
            init_soc = []
        end

        starting_batt_soc_kwh = init_soc .* batt_kwh

        #Only adds PV generation if there is also a battery
        critical_loads_kw .-= pv_kw_ac_hourly
        r2[:starting_batt_soc_kwh] = starting_batt_soc_kwh

    end

    r2[:batt_kw] = batt_kw
    r2[:batt_kwh] = batt_kwh
    r2[:critical_loads_kw] = critical_loads_kw
    diesel_kw = 0
    if "Generator" in keys(d)
        diesel_kw = get(d["Generator"], "size_kw", 0)
    end
    if microgrid_only
        diesel_kw = get(d, "Generator_mg_kw", 0)
    end
    
    #If gen capacity is 0 then base on diesel_kw
    #If num_gens is zero then either set to 1 or base on ceiling(diesel_kw / gen_capacity)
    gen_capacity = get(r, "gen_capacity", 0)
    num_gens = get(r, "num_gens", 1)

    if gen_capacity < 0.1
        if num_gens <= 1
            gen_capacity = diesel_kw
            num_gens = 1
        else
            gen_capacity = diesel_kw / num_gens
        end
    elseif num_gens == 0
        num_gens = ceil(Int, diesel_kw / gen_capacity)
    end

    r2[:gen_capacity] = gen_capacity
    r2[:num_gens] = num_gens

    return r2
end

"""
    return_backup_reliability(; critical_loads_kw::Vector, gen_operational_availability::Real = 0.9998, gen_failure_to_start::Real = 0.0066, 
        gen_failure_to_run::Real = 0.00157, num_gens::Int = 1, gen_capacity::Real = 0.0, num_battery_bins::Int = 100, max_outage_duration::Int = 96,
        batt_kw::Real = 0.0, batt_kwh::Real = 0.0, batt_charge_efficiency::Real = 0.948, batt_discharge_efficiency::Real = 0.948)::Array

Return an array of backup reliability calculations. Inputs can be unpacked from backup_reliability_inputs() dictionary

# Arguments
-critical_loads_kw::Vector                      vector of net critical loads                     
-gen_operational_availability::Real = 0.9998    Fraction of year generators not down for maintenance
-gen_failure_to_start::Real = 0.0066            Chance of generator starting given outage
-gen_failure_to_run::Real = 0.00157             Chance of generator failing in each hour of outage
-num_gens::Int = 1                              Number of generators
-gen_capacity::Real = 0.0                       Backup generator capacity
-num_battery_bins::Int = 100                    Internal value for modeling battery
-max_outage_duration::Int = 96                  Maximum outage hour modeled
-batt_kw::Real = 0.0                            Battery kW of power capacity
-batt_kwh::Real = 0.0                           Battery kWh of energy capacity
-batt_charge_efficiency::Real = 0.948           Efficiency of charging battery
-batt_discharge_efficiency::Real = 0.948        Efficiency of discharging battery
```
"""
function return_backup_reliability(; critical_loads_kw::Vector, gen_operational_availability::Real = 0.9998, gen_failure_to_start::Real = 0.0066, 
                                    gen_failure_to_run::Real = 0.00157, num_gens::Int = 1, gen_capacity::Real = 0.0, num_battery_bins::Int = 100, max_outage_duration::Int = 96,
                                    batt_kw::Real = 0.0, batt_kwh::Real = 0.0, batt_charge_efficiency::Real = 0.948, batt_discharge_efficiency::Real = 0.948)::Array
 
    
    #No reliability calculations if no generators
    if max_outage_duration == 0
        return []
        
    elseif gen_capacity < 0.1
        return []
    
    elseif batt_kw < 0.1
        return [survival_over_time_gen_only(critical_loads_kw, gen_operational_availability, gen_failure_to_start, gen_failure_to_run, num_gens, gen_capacity, max_outage_duration, marginal_survival = true),
                survival_over_time_gen_only(critical_loads_kw, gen_operational_availability, gen_failure_to_start, gen_failure_to_run, num_gens, gen_capacity, max_outage_duration, marginal_survival = false)]

    else
        return [survival_with_battery(critical_loads_kw, starting_batt_soc_kwh, gen_operational_availability, gen_failure_to_start, gen_failure_to_run, num_gens, gen_capacity, 
                                    batt_kwh, batt_kw, num_battery_bins, max_outage_duration, batt_charge_efficiency, batt_discharge_efficiency, marginal_survival = true),
                survival_with_battery(critical_loads_kw, starting_batt_soc_kwh, gen_operational_availability, gen_failure_to_start, gen_failure_to_run, num_gens, gen_capacity, 
                                    batt_kwh, batt_kw, num_battery_bins, max_outage_duration, batt_charge_efficiency, batt_discharge_efficiency, marginal_survival = false)] 

    end
end


function process_reliability_results(results)
    if results == []
        marginal_duration_means = []
        marginal_duration_mins = []
        marginal_final_resilience = []
        cumulative_duration_means = []
        cumulative_duration_mins = []
        cumulative_final_resilience = []
    else
        marginal_results = results[1]
        cumulative_results = results[2]
        marginal_duration_means = mean(marginal_results, dims = 1)
        marginal_duration_mins = minimum(marginal_results, dims = 1)
        marginal_final_resilience = marginal_results[:, end]
        cumulative_duration_means = mean(cumulative_results, dims = 1)
        cumulative_duration_mins = minimum(cumulative_results, dims = 1)
        cumulative_final_resilience = cumulative_results[:, end]
    end

    return Dict(
        "marginal_duration_means" => marginal_duration_means,
        "marginal_duration_mins" => marginal_duration_mins,
        "marginal_final_resilience" => marginal_final_resilience,
        "cumulative_duration_means" => cumulative_duration_means,
        "cumulative_duration_mins" => cumulative_duration_mins,
        "cumulative_final_resilience" => cumulative_final_resilience
    )
end


"""
	backup_reliability(p::REoptInputs, d::Dict)

Return dictionary of backup reliability results.

# Arguments
- `d::Dict`: REopt results dictionary. 
- `p::REoptInputs`: REopt Inputs Struct.
- `r::Dict`: Dictionary of inputs for reliability calculations. If r not included then uses all defaults. values read from dictionary:
    -gen_operational_availability::Real = 0.9998 (Fraction of year generators not down for maintenance)
    -gen_failure_to_start::Real = 0.0066 (Chance of generator starting given outage)
    -gen_failure_to_run::Real = 0.00157 (Chance of generator failing in each hour of outage)
    -num_gens::Int = 1  (Number of generators. Will be determined by code if set to 0 and gen capacity > 0.1)
    -gen_capacity::Real = 0.0 (Backup generator capacity. Will be determined by REopt optimization if set less than 0.1)
    -num_battery_bins::Int = 100 (Internal value for modeling battery)
    -max_outage_duration::Int = 96 (Maximum outage hour modeled)
    -microgrid_only::Bool = false (determines how generator, PV, and battery act during islanded mode)

"""
function backup_reliability(d::Dict, p::REoptInputs, r::Dict)
    reliability_inputs = backup_reliability_inputs(d, p; r)
	results = return_backup_reliability(; reliability_inputs... )
	process_reliability_results(results)
end