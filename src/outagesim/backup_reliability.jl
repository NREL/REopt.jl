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
    transition_prob(start_gen::Vector{Int}, end_gen::Vector{Int}, fail_prob::Real)

Return a vector of the probability of ``y`` generators working at the end of the period given ``x`` generators are working at the start of the period
and given a failure rate of ``fail_prob``. ``x`` = ``start_gen[i]`` and ``y`` = ``end_gen[i]`` for each i in the length of start gen. 
Start gen and end gen need to be the same length.

Function used to create transition probabilities in Markov matrix.

# Examples
```repl-julia
julia> transition_prob([1, 2, 3, 4], [0, 1, 2, 3], fail_prob=0.5)
4-element Vector{Float64}:
 0.5
 0.5
 0.375
 0.25
```
"""
function transition_prob(start_gen::Vector{Int}, end_gen::Vector{Int}, fail_prob::Real)::Vector{Float64} 
    return binomial.(start_gen, end_gen).*(1-fail_prob).^(end_gen).*(fail_prob).^(start_gen-end_gen)
end

"""
transition_prob(start_gen::Vector{Vector{Int}}, end_gen::Vector{Vector{Int}}, fail_prob::Vector{<:Real})::Vector{Float64}

Transition probability for multiple generator types. 
Return the probability of going from i_t to j_t generators for each of generator type t given a failure rate of 
``fail_prob`` for each i,j,t in vector of vectors ``start_gen`` and ``end_gen``.

Function used to create transition probabilities in Markov matrix.

# Examples
```repl-julia
fail_prob = [0.2, 0.5]; num_generators = [1,1]
num_generators_working = reshape(collect(Iterators.product((0:g for g in num_generators)...)), :, 1)
starting_gens = vec(repeat(num_generators_working, outer = prod(num_generators .+ 1)))
ending_gens = repeat(vec(num_generators_working), inner = prod(num_generators .+ 1))

julia> transition_prob(starting_gens, ending_gens, fail_prob)
16-element Vector{Float64}:
 1.0
 0.2
 ...
 0.4
```
"""
function transition_prob(start_gen::Vector, end_gen::Vector, fail_prob::Vector{<:Real})::Vector{Float64} 
    start_gen_matrix = hcat(collect.(start_gen)...)
    end_gen_matrix = hcat(collect.(end_gen)...)

    transitions =  [binomial.(start_gen_matrix[i, :], end_gen_matrix[i, :]).*(1-fail_prob[i]).^(end_gen_matrix[i, :]).*(fail_prob[i]).^(start_gen_matrix[i, :].-end_gen_matrix[i, :]) for i in 1:length(fail_prob)]
    return .*(transitions...)
end


"""
    markov_matrix(num_generators::Int, fail_prob::Real)

Return a ``num_generators``+1 by ``num_generators``+1 matrix of transition probabilities of going from n (row) to n' (column) given probability ``fail_prob``

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
function markov_matrix(num_generators::Int, fail_prob::Real)::Matrix{Float64} 
    #Creates Markov matrix for generator transition probabilities
    M = reshape(transition_prob(repeat(0:num_generators, outer = num_generators + 1), 
                                repeat(0:num_generators, inner = num_generators+1), 
                                fail_prob), 
                num_generators+1, num_generators+1)
    replace!(M, NaN => 0)
    return M
end

"""
    markov_matrix(num_generators::Vector{Int}, fail_prob::Vector{<:Real})::Matrix{Float64} 

Markov Matrix for multiple generator types. 
Return an prod(``num_generators``.+1) by prod(``num_generators``.+1) matrix of transition probabilities of going from n (row) to n' (column) given probability ``fail_prob``

Rows denote starting generators and columns denote ending generators. 
Generator availability scenarios are ordered such that the number of the leftmost generator type increments fastest.
For example, if `num_generators` = [2, 1], then the rows of the returned matrix correspond to the number of working generators by type as follows:
row    working generators
1           (0, 0) 
2           (1, 0)
3           (2, 0)
4           (0, 1)
5           (1, 1)
6           (2, 1)

# Arguments
- `num_generators::Vec{Int}`: Vector of the number of generators of each type 
- `fail_prob::Vec{Real}`: vector of probability of failure of each generator type

# Examples
```repl-julia
julia> markov_matrix([2, 1], [0.1, 0.25])
6×6 Matrix{Float64}:
 1.0   0.0     0.0     0.0  0.0     0.0
 0.1   0.0     0.225   0.0  0.0     0.675
 0.01  0.81    0.045   0.0  0.0     0.135
 0.0   0.25    0.0     0.0  0.75    0.0
 0.9   0.025   0.0     0.0  0.075   0.0
 0.18  0.0025  0.2025  0.0  0.0075  0.6075
```
"""
function markov_matrix(num_generators::Vector{Int}, fail_prob::Vector{<:Real})::Matrix{Float64} 

    num_generators_working = reshape(collect(Iterators.product((0:g for g in num_generators)...)), :, 1)
    starting_gens = vec(repeat(num_generators_working, outer = prod(num_generators .+ 1)))
    ending_gens = repeat(vec(num_generators_working), inner = prod(num_generators .+ 1))

    #Creates Markov matrix for generator transition probabilities
    M = reshape(transition_prob(starting_gens, ending_gens, fail_prob), prod(num_generators.+1), prod(num_generators .+1))
    replace!(M, NaN => 0)
    return M
end
"""
    starting_probabilities(num_generators::Int, generator_operational_availability::Real, generator_failure_to_start::Real)::Matrix{Float64}

Return a 1 by ``num_generators`` + 1 matrix (row vector) of the probability that each number of generators
is both operationally available (``generator_operational_availability``) and avoids a Failure to Start (``failure_to_start``) 
in an inital time step

The first element denotes no generators successfully starts and element n denotes n-1 generators start

# Arguments
- `num_generators::Int`: the number of generators 
- `generator_operational_availability::Real`: Operational Availability. The chance that a generator will be available (not down for maintenance) at the start of the outage
- `generator_failure_to_start::Real`: Failure to Start. The chance that a generator fails to successfully start and take load.

# Examples
```repl-julia
julia> starting_probabilities(2, 0.99, 0.05)
1×3 Matrix{Float64}:
 0.00354025  0.11192  0.88454
```
"""
function starting_probabilities(num_generators::Int, generator_operational_availability::Real, generator_failure_to_start::Real)::Matrix{Float64} 
    starting_vec = markov_matrix(num_generators, (1-generator_operational_availability) + generator_failure_to_start*generator_operational_availability)[end, :] 
    return reshape(starting_vec, 1, length(starting_vec))
end

"""
    starting_probabilities(num_generators::Vector{Int}, generator_operational_availability::Vector{<:Real}, generator_failure_to_start::Vector{<:Real})::Matrix{Float64}

Starting Probabilities for multiple generator types. 
Return a 1 by prod(``num_generators`` .+ 1) matrix (row vector) of the probability that each number of generators 
(differentiated by generator type) is both operationally available (``generator_operational_availability``) 
and avoids a Failure to Start (``failure_to_start``) in an inital time step

Generator availability scenarios are ordered such that the number of the leftmost generator type increments fastest.
For example, if `num_generators` = [2, 1], then the columns of the returned matrix correspond to the number of working generators by type as follows:
col    working generators
1           (0, 0) 
2           (1, 0)
3           (2, 0)
4           (0, 1)
5           (1, 1)
6           (2, 1)

# Arguments
- `num_generators::Vec{Int}`: the number of generators of each type 
- `generator_operational_availability::Vec{Real}`: Operational Availability. The chance that a generator will be available (not down for maintenance) at the start of the outage
- `generator_failure_to_start::Vec{Real}`: Failure to Start. The chance that a generator fails to successfully start and take load.

# Examples
```repl-julia
julia> starting_probabilities([2, 1], [0.99,0.95], [0.05, 0.1])
1×6 Matrix{Float64}:
    0.000513336  0.0162283  0.128258  0.00302691  0.0956912  0.756282
```
"""
function starting_probabilities(num_generators::Vector{Int}, generator_operational_availability::Vector{<:Real}, generator_failure_to_start::Vector{<:Real})::Matrix{Float64} 
    starting_vec = markov_matrix(num_generators, (1 .- generator_operational_availability) + generator_failure_to_start .* generator_operational_availability)[end, :] 
    return reshape(starting_vec, 1, length(starting_vec))
end

"""
    bin_battery_charge(batt_soc_kwh::Vector, num_bins::Int, battery_size_kwh::Real)::Vector{Int}

Return a vector the same length as ``batt_soc_kwh`` of discritized battery charge bins

The first bin denotes zero battery charge, and each additional bin has size of ``battery_size_kwh``/(``num_bins``-1)
Values are rounded to nearest bin.

# Examples
```repl-julia
julia>  bin_battery_charge([30, 100, 170.5, 250, 251, 1000], 11, 1000)
6-element Vector{Int64}:
  1
  2
  3
  3
  4
 11
```
"""
function bin_battery_charge(batt_soc_kwh::Vector, num_bins::Int, battery_size_kwh::Real)::Vector{Int}  
    #Bins battery into discrete portions. Zero is one of the bins. 
    bin_size = battery_size_kwh / (num_bins-1)
    return min.(num_bins, round.(batt_soc_kwh./bin_size).+1)
end

"""
    generator_output(num_generators::Int, generator_size_kw::Real)::Vector{Float64} 

Return a ``num_generators``+1 length vector of maximum generator capacity given 0 to ``num_generators`` are available
# Examples
```repl-julia
julia>  generator_output(3, 250)
6-element Vector{Int64}:
0
250
500
750
```
"""
function generator_output(num_generators::Int, generator_size_kw::Real)::Vector{Float64} 
    #Returns vector of maximum generator output
    return collect(0:num_generators).*generator_size_kw
end

"""
    generator_output(num_generators::Vector{Int}, generator_size_kw::Vector{<:Real})::Vector{Float64} 

Generator output for multiple generator types
Return a prod(``num_generators`` .+ 1) length vector of maximum generator capacity given 0 to ``num_generators`` of each type are available

Generator availability scenarios are ordered such that the number of the leftmost generator type increments fastest.
For example, if `num_generators` = [2, 1], then the elements of the returned vector correspond to the number of working generators by type as follows:
index    working generators
1           (0, 0) 
2           (1, 0)
3           (2, 0)
4           (0, 1)
5           (1, 1)
6           (2, 1)

#Examples
```repl-julia
generator_output([2,1], [250, 300])
6-element Vector{Float64}:
   0.0
 250.0
 500.0
 300.0
 550.0
 800.0
```
"""
function generator_output(num_generators::Vector{Int}, generator_size_kw::Vector{<:Real})::Vector{Float64} 
    gens_working = (0:g for g in num_generators)
    num_generators_working = reshape(collect(Iterators.product(gens_working...)), :, 1)
    #Returns vector of maximum generator output
    return vec([sum(gw[i] * generator_size_kw[i] for i in 1:length(generator_size_kw)) for gw in num_generators_working])
end

"""
    get_maximum_generation(battery_size_kw::Real, generator_size_kw::Real, bin_size::Real, 
                           num_bins::Int, num_generators::Int, battery_discharge_efficiency::Real)::Matrix{Float64}

Return a matrix of maximum total system output.

Rows denote battery state of charge bin and columns denote number of available generators, with the first column denoting zero available generators.

# Arguments
- `battery_size_kw::Real`: battery inverter size
- `generator_size_kw::Real`: maximum output from single generator. 
- `bin_size::Real`: size of discretized battery soc bin. is equal to battery_size_kwh / (num_bins - 1) 
- `num_bins::Int`: number of battery bins. 
- `num_generators::Int`: number of generators in microgrid.
- `battery_discharge_efficiency::Real`: battery_discharge_efficiency = battery_discharge / battery_reduction_in_soc

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
function get_maximum_generation(battery_size_kw::Real, generator_size_kw::Real, bin_size::Real, 
                   num_bins::Int, num_generators::Int, battery_discharge_efficiency::Real)::Matrix{Float64}
    #Returns a matrix of maximum hourly generation (rows denote number of generators starting at 0, columns denote battery bin)
    N = num_generators + 1
    M = num_bins
    max_system_output = zeros(M, N) 
    for i in 1:M
       max_system_output[i, :] = generator_output(num_generators, generator_size_kw) .+ min(battery_size_kw, (i-1)*bin_size*battery_discharge_efficiency)
    end
    return max_system_output
end

"""
    get_maximum_generation(battery_size_kw::Real, generator_size_kw::Vector{<:Real}, bin_size::Real, 
        num_bins::Int, num_generators::Vector{Int}, battery_discharge_efficiency::Real)::Matrix{Float64}

Maximum generation calculation for multiple generator types
Return a matrix of maximum total system output.

Rows denote battery state of charge bin and columns denote number of available generators, with the first column denoting zero available generators.

# Arguments
- `battery_size_kw::Real`: battery inverter size
- `generator_size_kw::Vector{Real}`: maximum output from single generator for each generator type. 
- `bin_size::Real`: size of discretized battery soc bin. is equal to battery_size_kwh / (num_bins - 1) 
- `num_bins::Int`: number of battery bins. 
- `num_generators::Vector{Int}`: number of generators by type in microgrid.
- `battery_discharge_efficiency::Real`: battery_discharge_efficiency = battery_discharge / battery_reduction_in_soc

# Examples
```repl-julia
julia>  get_maximum_generation(200, [50, 125], 100, 3, [2, 1], 0.98)
3×6 Matrix{Float64}:
   0.0   50.0  100.0  125.0  175.0  225.0
  98.0  148.0  198.0  223.0  273.0  323.0
 196.0  246.0  296.0  321.0  371.0  421.0
```
"""
function get_maximum_generation(battery_size_kw::Real, generator_size_kw::Vector{<:Real}, bin_size::Real, 
    num_bins::Int, num_generators::Vector{Int}, battery_discharge_efficiency::Real)::Matrix{Float64}
    #Returns a matrix of maximum hourly generation (rows denote number of generators starting at 0, columns denote battery bin)
    N = prod(num_generators .+ 1)
    M = num_bins
    max_system_output = zeros(M, N)
    for i in 1:M
        max_system_output[i, :] = generator_output(num_generators, generator_size_kw) .+ min(battery_size_kw, (i-1)*bin_size*battery_discharge_efficiency)
    end
    return max_system_output
end

"""
    battery_bin_shift(excess_generation_kw::Vector, bin_size::Real, battery_size_kw::Real, battery_charge_efficiency::Real, battery_discharge_efficiency::Real)::Vector{Int} 

Return a vector of number of bins battery is shifted by

Bins are the discritized battery sizes, with the first bin denoting zero charge and the last bin denoting full charge. Thus, if there are 101 bins, then each bin denotes 
a one percent difference in battery charge. The battery will attempt to dispatch to meet critical loads not met by other generation sources, and will charge from excess generation. 

# Arguments
- `excess_generation_kw::Vector`: maximum generator output minus net critical load for each number of working generators
- `bin_size::Real`: size of battery bin
- `battery_size_kw::Real`: inverter size
- `battery_charge_efficiency::Real`: battery_charge_efficiency = increase_in_soc_kwh / grid_input_kwh 
- `battery_discharge_efficiency::Real`: battery_discharge_efficiency = battery_discharge / battery_reduction_in_soc

#Examples
```repl-julia
julia>
excess_generation_kw = [-500, -120, 0, 50, 175, 400]
bin_size = 100
battery_size_kw = 300
battery_bin_shift(excess_generation_kw, bin_size, battery_size_kw, 1, 1)
7-element Vector{Int64}:
 -3
 -1
  0
  0
  0
  2
  3
  ```
"""
function battery_bin_shift(excess_generation_kw::Vector{<:Real}, bin_size::Real, battery_size_kw::Real,
                                battery_charge_efficiency::Real, battery_discharge_efficiency::Real)::Vector{Int} 
    #Determines how many battery bins to shift by
    #Lose energy charging battery and use more energy discharging battery
    #Need to shift battery up by less and down by more.
    
    #positive excess generation 
    excess_generation_kw[excess_generation_kw .> 0] = excess_generation_kw[excess_generation_kw .> 0] .* battery_charge_efficiency
    excess_generation_kw[excess_generation_kw .< 0] = excess_generation_kw[excess_generation_kw .< 0] ./ battery_discharge_efficiency
    #Battery cannot charge or discharge more than its capacity
    excess_generation_kw[excess_generation_kw .> battery_size_kw] .= battery_size_kw
    excess_generation_kw[excess_generation_kw .< -battery_size_kw] .= -battery_size_kw
    shift = round.(excess_generation_kw ./ bin_size)
    return shift
end

"""
    shift_gen_battery_prob_matrix!(gen_battery_prob_matrix::Matrix, shift_vector::Vector{Int})

Updates ``gen_battery_prob_matrix`` in place to account for change in battery state of charge bin

shifts probabiilities in column i by ``shift_vector``[i] positions, accounting for accumulation at 0 or full soc   

#Examples
```repl-julia
gen_battery_prob_matrix = [0.6 0.3;
                           0.2 0.3;
                           0.1 0.2;
                           0.1 0.2]
shift_vector = [-1, 2]
shift_gen_battery_prob_matrix!(gen_battery_prob_matrix, shift_vector)
gen_battery_prob_matrix
4×2 Matrix{Float64}:
 0.8  0.0
 0.1  0.0
 0.1  0.3
 0.0  0.7
```
"""
function shift_gen_battery_prob_matrix!(gen_battery_prob_matrix::Matrix, shift_vector::Vector{Int})
    M = size(gen_battery_prob_matrix, 1)

    for i in 1:length(shift_vector) 
        s = shift_vector[i]
        if s < 0 
            gen_battery_prob_matrix[:, i] = circshift(view(gen_battery_prob_matrix, :, i), s)
            gen_battery_prob_matrix[1, i] += sum(view(gen_battery_prob_matrix, max(2,M+s+1):M, i))
            gen_battery_prob_matrix[max(2,M+s+1):M, i] .= 0
        elseif s > 0
            gen_battery_prob_matrix[:, i] = circshift(view(gen_battery_prob_matrix, :, i), s)
            gen_battery_prob_matrix[end, i] += sum(view(gen_battery_prob_matrix, 1:min(s,M-1), i))
            gen_battery_prob_matrix[1:min(s,M-1), i] .= 0
        end
    end
end

"""
    survival_gen_only(;critical_load::Vector, generator_operational_availability::Real, generator_failure_to_start::Real, generator_failure_to_run::Real, num_generators::Int,
                                generator_size_kw::Real, max_duration::Int, marginal_survival = true)::Matrix{Float64}

Return a matrix of probability of survival with rows denoting outage start timestep and columns denoting outage duration

Solves for probability of survival given only backup generators (no battery backup). 
If ``marginal_survival`` = true then result is chance of surviving in given outage timestep, 
if ``marginal_survival`` = false then result is chance of surviving up to and including given outage timestep.

# Arguments
- `net_critical_loads_kw::Vector`: 8760 vector of system critical loads. 
- `generator_operational_availability::Union{Real, Vector{<:Real}}`: Operational Availability of backup generators.
- `generator_failure_to_start::Union{Real, Vector{<:Real}}`: probability of generator Failure to Start and support load. 
- `generator_failure_to_run::Union{Real, Vector{<:Real}}`: hourly Failure to Run probability. failure_to_run is 1/MTTF (mean time to failure). 
- `num_generators::Union{Int, Vector{Int}}`: number of generators in microgrid.
- `generator_size_kw::Union{Real, Vector{<:Real}}`: size of generator.
- `max_duration::Int`: maximum outage duration in timesteps.
- `marginal_survival::Bool`: indicates whether results are probability of survival in given outage hour or probability of surviving up to and including hour.

# Examples
Given failure_to_run = 0.2, the chance of no generators failing in 0.64 in hour 1, 0.4096 in hour 2, and 0.262144 in hour 3
Chance of 2 generators failing is 0.04 in hour 1, 0.1296 by hour 1, and 0.238144 by hour 3   
```repl-julia
julia> net_critical_loads_kw = [1,2,2,1]; generator_operational_availability = 1; failure_to_start = 0.0; failure_to_run = 0.2; num_generators = 2; generator_size_kw = 1; max_duration = 3;
julia> survival_gen_only(net_critical_loads_kw=net_critical_loads_kw, generator_operational_availability=generator_operational_availability, 
                                generator_failure_to_start=failure_to_start, generator_failure_to_run=failure_to_run, num_generators=num_generators, 
                                generator_size_kw=generator_size_kw, max_duration=max_duration, marginal_survival = true)
4×3 Matrix{Float64}:
 0.96  0.4096  0.262144
 0.64  0.4096  0.761856
 0.96  0.8704  0.761856
 0.96  0.8704  0.262144

julia> survival_gen_only(critical_load=critical_loads_kw, generator_operational_availability=generator_operational_availability, 
                                generator_failure_to_start=failure_to_start, generator_failure_to_run=failure_to_run, num_generators=num_generators, 
                                generator_size_kw=generator_size_kw, max_duration=max_duration, marginal_survival = false)
4×3 Matrix{Float64}:
 0.96  0.4096  0.262144
 0.64  0.4096  0.393216
 0.64  0.6144  0.557056
 0.96  0.8704  0.262144
```
"""
function survival_gen_only(;
    net_critical_loads_kw::Vector, 
    generator_operational_availability::Union{Real, Vector{<:Real}}, 
    generator_failure_to_start::Union{Real, Vector{<:Real}}, 
    generator_failure_to_run::Union{Real, Vector{<:Real}},
    num_generators::Union{Int, Vector{Int}}, 
    generator_size_kw::Union{Real, Vector{<:Real}},
    max_duration::Int,
    marginal_survival = true)::Matrix{Float64} 

    t_max = length(net_critical_loads_kw)
    
    generator_production = generator_output(num_generators, generator_size_kw) 
    #Initialize lost load matrix
    survival_probability_matrix = zeros(t_max, max_duration)
    #initialize amount of extra generation for each critical load hour and each amount of generators
    generator_markov_matrix = markov_matrix(num_generators, generator_failure_to_run)
  
    #Get starting generator vector
    starting_gens = starting_probabilities(num_generators, generator_operational_availability, generator_failure_to_start) #initialize gen battery prob matrix

    for t  = 1:t_max
        gen_probs = starting_gens
        
        for d in 1:max_duration
            survival = ones(1, length(generator_production))
            
            h = mod(t + d - 2, t_max) + 1 #determines index accounting for looping around year
            net_gen = generator_production .- net_critical_loads_kw[h]
            survival[net_gen .< 0] .= 0

            gen_probs *= generator_markov_matrix #Update to account for generator failures
            survival_chance = gen_probs .* survival #Elementwise, probability that i gens is available * probability of surviving if i gens is available
            
            if marginal_survival == false
                gen_probs = survival_chance
            end
            
            #update total probability of survival for given outage start time and outage duration
            survival_probability_matrix[t, d] = sum(survival_chance)
        end
    end
    return survival_probability_matrix
end

"""
    survival_with_battery(;net_critical_loads_kw::Vector, battery_starting_soc_kwh::Vector, generator_operational_availability::Real, generator_failure_to_start::Real, 
                        generator_failure_to_run::Real, num_generators::Int, generator_size_kw::Real, battery_size_kwh::Real, battery_size_kw::Real, num_bins::Int, 
                        max_outage_duration::Int, battery_charge_efficiency::Real, battery_discharge_efficiency::Real, marginal_survival = true)::Matrix{Float64} 

Return a matrix of probability of survival with rows denoting outage start and columns denoting outage duration

Solves for probability of survival given both networked generators and battery backup. 
If ``marginal_survival`` = true then result is chance of surviving in given outage hour, 
if ``marginal_survival`` = false then result is chance of surviving up to and including given outage hour.

# Arguments
- `net_critical_loads_kw::Vector`: 8760 vector of system critical loads minus solar generation.
- `battery_starting_soc_kwh::Vector`: 8760 vector of battery charge (kwh) for each hour of year. 
- `generator_operational_availability::Real`: Operational Availability of backup generators.
- `generator_failure_to_start::Real`: probability of generator Failure to Start and support load. 
- `generator_failure_to_run::Real`: hourly Failure to Run probability. failure_to_run is 1/MTTF (mean time to failure). 
- `num_generators::Int`: number of generators in microgrid.
- `generator_size_kw::Real`: size of generator.
- `battery_size_kwh::Real`: energy capacity of battery system.
- `battery_size_kw::Real`: battery system inverter size.
- `num_battery_bins::Int`: number of battery bins. 
- `max_outage_duration::Int`: maximum outage duration in hours.
- `battery_charge_efficiency::Real`: battery_charge_efficiency = increase_in_soc_kwh / grid_input_kwh 
- `battery_discharge_efficiency::Real`: battery_discharge_efficiency = battery_discharge / battery_reduction_in_soc
- `marginal_survival::Bool`: indicates whether results are probability of survival in given outage hour or probability of surviving up to and including hour.

# Examples
Given failure_to_run = 0.2, the chance of no generators failing in 0.64 in hour 1, 0.4096 in hour 2, and 0.262144 in hour 3
Chance of 2 generators failing is 0.04 in hour 1, 0.1296 by hour 2, and 0.238144 by hour 3   
```repl-julia
julia> net_critical_loads_kw = [1,2,2,1]; battery_starting_soc_kwh = [1,1,1,1];  max_outage_duration = 3;
julia> num_generators = 2; generator_size_kw = 1; generator_operational_availability = 1; failure_to_start = 0.0; failure_to_run = 0.2;
julia> num_battery_bins = 3; battery_size_kwh = 2; battery_size_kw = 1;  battery_charge_efficiency = 1; battery_discharge_efficiency = 1;

julia> survival_with_battery(net_critical_loads_kw=net_critical_loads_kw, battery_starting_soc_kwh=battery_starting_soc_kwh, 
                            generator_operational_availability=generator_operational_availability, generator_failure_to_start=failure_to_start, 
                            generator_failure_to_run=failure_to_run, num_generators=num_generators, generator_size_kw=generator_size_kw, 
                            battery_size_kwh=battery_size_kwh, battery_size_kw = battery_size_kw, num_battery_bins=num_battery_bins, 
                            max_outage_duration=max_outage_duration, battery_charge_efficiency=battery_charge_efficiency, 
                            battery_discharge_efficiency=battery_discharge_efficiency, marginal_survival = true)
4×3 Matrix{Float64}:
1.0   0.8704  0.557056
0.96  0.6144  0.77824
0.96  0.896   0.8192
1.0   0.96    0.761856

julia> survival_with_battery(net_critical_loads_kw=net_critical_loads_kw, battery_starting_soc_kwh=battery_starting_soc_kwh, 
                            generator_operational_availability=generator_operational_availability, generator_failure_to_start=failure_to_start, 
                            generator_failure_to_run=failure_to_run, num_generators=num_generators, generator_size_kw=generator_size_kw, 
                            battery_size_kwh=battery_size_kwh, battery_size_kw = battery_size_kw, num_battery_bins=num_battery_bins, 
                            max_outage_duration=max_outage_duration, battery_charge_efficiency=battery_charge_efficiency, 
                            battery_discharge_efficiency=battery_discharge_efficiency, marginal_survival = false)
4×3 Matrix{Float64}:
1.0   0.8704  0.557056
0.96  0.6144  0.57344
0.96  0.896   0.8192
1.0   0.96    0.761856
```
"""
function survival_with_battery(;
    net_critical_loads_kw::Vector, 
    battery_starting_soc_kwh::Vector, 
    generator_operational_availability::Union{Real, Vector{<:Real}}, 
    generator_failure_to_start::Union{Real, Vector{<:Real}},
    generator_failure_to_run::Union{Real, Vector{<:Real}},
    num_generators::Union{Int, Vector{Int}},
    generator_size_kw::Union{Real, Vector{<:Real}}, 
    battery_size_kwh::Real, 
    battery_size_kw::Real, 
    num_battery_bins::Int, 
    max_outage_duration::Int, 
    battery_charge_efficiency::Real,
    battery_discharge_efficiency::Real,
    marginal_survival = true)::Matrix{Float64} 

    t_max = length(net_critical_loads_kw)
    
    #bin size is battery storage divided by num bins-1 because zero is also a bin
    bin_size = battery_size_kwh / (num_battery_bins-1)
     
    #bin initial battery 
    starting_battery_bins = bin_battery_charge(battery_starting_soc_kwh, num_battery_bins, battery_size_kwh) 
    #For easier indice reading
    M = num_battery_bins
    if length(num_generators) == 1
        N = num_generators + 1
    else
        N = prod(num_generators .+ 1)
    end
    #Initialize lost load matrix
    survival_probability_matrix = zeros(t_max, max_outage_duration) 
    #initialize vectors and matrices
    generator_markov_matrix = markov_matrix(num_generators, generator_failure_to_run) 
    gen_prod = generator_output(num_generators, generator_size_kw)
    maximum_generation = get_maximum_generation(battery_size_kw, generator_size_kw, bin_size, num_battery_bins, num_generators, battery_discharge_efficiency)
    starting_gens = starting_probabilities(num_generators, generator_operational_availability, generator_failure_to_start) 

    #loop through outage time
    for t = 1:t_max
        gen_battery_prob_matrix = zeros(M, N)
        gen_battery_prob_matrix[starting_battery_bins[t], :] = starting_gens
        
        #loop through outage duration
        for d in 1:max_outage_duration 
            survival = ones(M, N)
            h = mod(t + d - 2, t_max) + 1 #determines index accounting for looping around year
            
            excess_generation_kw = gen_prod .- net_critical_loads_kw[h]
            max_net_generation = maximum_generation .- net_critical_loads_kw[h]

            #System fails if net generation is negative (cannot meet load)
            survival[max_net_generation .< 0, ] .= 0

            #Update probabilities to account for generator failures
            gen_battery_prob_matrix *= generator_markov_matrix 

            #Update survival probabilities
            #Elementwise, probability that i gens is available * probability of surviving if i gens is available
            survival_chance = gen_battery_prob_matrix .* survival 

            #If marginal survival is false then remove probabilities which did not meet load
            if marginal_survival == false
                gen_battery_prob_matrix = survival_chance
            end

            survival_probability_matrix[t, d] = sum(survival_chance)
            #Update generation battery probability matrix to account for battery shifting
            shift_gen_battery_prob_matrix!(gen_battery_prob_matrix, battery_bin_shift(excess_generation_kw, bin_size, battery_size_kw, battery_charge_efficiency, battery_discharge_efficiency))
        end
    end
    return survival_probability_matrix
end

"""
    backup_reliability_reopt_inputs(;d::Dict, p::REoptInputs, r::Dict)::Dict

Return a dictionary of inputs required for backup reliability calculations. 

# Arguments
- `d::Dict`: REopt results dictionary. 
- `r::Dict`: Dictionary of inputs for reliability calculations. If r not included then uses all defaults. values read from dictionary:
    -generator_operational_availability::Real = 0.9998      Fraction of year generators not down for maintenance
    -generator_failure_to_start::Real = 0.0066              Chance of generator starting given outage
    -generator_failure_to_run::Real = 0.00157               Chance of generator failing in each hour of outage
    -num_generators::Int = 1                                Number of generators. Will be determined by code if set to 0 and gen capacity > 0.1
    -generator_size_kw::Real = 0.0                          Backup generator capacity. Will be determined by REopt optimization if set less than 0.1
    -num_battery_bins::Int = 101                            Internal value for discretely modeling battery state of charge
    -max_outage_duration::Int = 96                          Maximum outage hour modeled
    -microgrid_only::Bool = false                           Boolean to specify if only microgrid upgraded technologies run during grid outage 
"""
function backup_reliability_reopt_inputs(;d::Dict, p::REoptInputs, r::Dict = Dict())::Dict
    zero_array = zeros(length(p.time_steps))
    net_critical_loads_kw = p.s.electric_load.critical_loads_kw

    r2 = dictkeys_tosymbols(r)
    
    #TODO Change CHP to meet capacity not load
    if "CHP" in keys(d)
        chp_generation =  get(d["CHP"], "size_kw", 0)
        net_critical_loads_kw .-= chp_generation
    end

    microgrid_only = get(r, "microgrid_only", false)

    pv_kw_ac_hourly = zero_array
    if !(
            microgrid_only && 
            !Bool(get(d, "PV_upgraded", false))
        ) && 
        "PV" in keys(d)

        pv_kw_ac_hourly = (
            get(d["PV"], "year_one_to_battery_series_kw", zero_array)
            + get(d["PV"], "year_one_curtailed_production_series_kw", zero_array)
            + get(d["PV"], "year_one_to_load_series_kw", zero_array)
            + get(d["PV"], "year_one_to_grid_series_kw", zero_array)
        )
    end

    battery_size_kwh = 0
    battery_size_kw = 0
    if "ElectricStorage" in keys(d)
        #TODO change to throw error if multiple storage types
        for b in p.s.storage.types.elec
            battery_charge_efficiency = p.s.storage.attr[b].charge_efficiency
            battery_discharge_efficiency = p.s.storage.attr[b].discharge_efficiency
        end
            
        battery_size_kwh = get(d["ElectricStorage"], "size_kwh", 0)
        battery_size_kw = get(d["ElectricStorage"], "size_kw", 0)
        init_soc = get(d["ElectricStorage"], "year_one_soc_series_fraction", [])

        if microgrid_only && !Bool(get(d, "storage_upgraded", false))
            battery_size_kwh = 0
            battery_size_kw = 0
            init_soc = []
        end

        battery_starting_soc_kwh = init_soc .* battery_size_kwh

        #Only subtracts PV generation if there is also a battery
        net_critical_loads_kw .-= pv_kw_ac_hourly
        r2[:battery_starting_soc_kwh] = battery_starting_soc_kwh

    end

    r2[:battery_size_kw] = battery_size_kw
    r2[:battery_size_kwh] = battery_size_kwh
    r2[:net_critical_loads_kw] = net_critical_loads_kw
    diesel_kw = 0
    if "Generator" in keys(d)
        diesel_kw = get(d["Generator"], "size_kw", 0)
    end
    if microgrid_only
        diesel_kw = get(d, "Generator_mg_kw", 0)
    end
    
    #If gen capacity is 0 then base on diesel_kw
    #If num_generators is zero then either set to 1 or base on ceiling(diesel_kw / generator_size_kw)
    generator_size_kw = get(r, "generator_size_kw", 0)
    num_generators = get(r, "num_generators", 1)
    if length(num_generators) == 1
        if generator_size_kw < 0.1
            if num_generators == 0
                generator_size_kw = diesel_kw
                num_generators = 1
            else
                generator_size_kw = diesel_kw / num_generators
            end
        elseif num_generators == 0
            num_generators = ceil(Int, diesel_kw / generator_size_kw)
        end
    else
        nt = length(num_generators)
        if length(generator_size_kw) != nt
            generator_size_kw = [diesel_kw / sum(num_generators) for _ in 1:nt]
        end
    end

    r2[:generator_size_kw] = generator_size_kw
    r2[:num_generators] = num_generators

    return r2
end

"""
    backup_reliability_inputs(;r::Dict)::Dict

Return a dictionary of inputs required for backup reliability calculations. 
***NOTE*** PV production only added if battery storage is also available to manage variability

# Arguments
- `r::Dict`: Dictionary of inputs for reliability calculations.
    inputs of r:
    -critical_loads_kw::Array                   Critical loads per time step. (Required input)
    -microgrid_only::Bool = false               Boolean to specify if only microgrid upgraded technologies run during grid outage 
    -chp_size_kw::Real                          CHP capacity. 
    -pv_size_kw::Real                           Size of PV System
    -pv_production_factor_series::Array         PV production factor per time step (required if pv_size_kw in dictionary)
    -pv_migrogrid_upgraded::Bool                If true then PV runs during outage if microgrid_only = TRUE (defaults to false)
    -battery_size_kw::Real                      Battery capacity. If no battery installed then PV disconnects from system during outage
    -battery_size_kwh::Real                     Battery energy storage capacity
    -charge_efficiency::Real                    Battery charge efficiency
    -discharge_efficiency::Real                 Battery discharge efficiency
    -battery_starting_soc_series_fraction            Battery state of charge in each hour (if not input then defaults to battery size)
    -generator_operational_availability= 0.9998 Likelihood generator being available in given hour
    -generator_failure_to_start::Real = 0.0066  Chance of generator starting given outage
    -generator_failure_to_run::Real = 0.00157   Chance of generator failing in each hour of outage
    -num_generators::Int = 1                    Number of generators. Will be determined by code if set to 0 and gen capacity > 0.1
    -generator_size_kw::Real = 0.0              Backup generator capacity. Will be determined by REopt optimization if set less than 0.1
    -num_battery_bins::Int = 101                Internal value for discretely modeling battery state of charge
    -max_outage_duration::Int = 96              Maximum outage hour modeled

#Examples
```repl-julia
julia> r = Dict("critical_loads_kw" => [1,2,1,1], "generator_operational_availability" => 1, "generator_failure_to_start" => 0.0,
                "generator_failure_to_run" => 0.2, "num_generators" => 2, "generator_size_kw" => 1, 
                "max_outage_duration" => 3, "battery_size_kw" =>2, "battery_size_kwh" => 4)
julia>    backup_reliability_inputs(r = r)
Dict{Any, Any} with 11 entries:
  :num_generators                     => 2
  :battery_starting_soc_kwh           => [4.0, 4.0, 4.0, 4.0]
  :max_outage_duration                => 3
  :generator_size_kw                  => 1
  :generator_failure_to_start         => 0.0
  :battery_size_kwh                   => 4
  :battery_size_kw                    => 2
  :net_critical_loads_kw              => Real[1.0, 2.0, 1.0, 1.0]
  :generator_failure_to_run           => 0.2
  :generator_operational_availability => 1
  :critical_loads_kw                  => Real[1.0, 2.0, 1.0, 1.0]
```
"""
function backup_reliability_inputs(;r::Dict)::Dict
    invalid_args = String[]
    r2 = dictkeys_tosymbols(r)

    generator_inputs = [:generator_operational_availability, :generator_failure_to_start, :generator_failure_to_run, :num_generators, :generator_size_kw]
    for g in generator_inputs
        if g in keys(r2) && isa(r2[g], Array) && length(r2[g]) == 1
        r2[g] = r2[g][1]
        end
    end
    
    r2[:net_critical_loads_kw] = r2[:critical_loads_kw]
    zero_array = zeros(length(r2[:net_critical_loads_kw]))

    if :chp_size_kw in keys(r2)
        r2[:net_critical_loads_kw] .-= r2[:chp_size_kw]
    end

    microgrid_only = get(r2, :microgrid_only, false)

    pv_kw_ac_hourly = zero_array
    if :pv_size_kw in keys(r2)
        if :pv_production_factor_series in keys(r2)
            pv_kw_ac_hourly = r2[:pv_size_kw] .* r2[:pv_production_factor_series]
        else
            push!(invalid_args, "pv_size_kw added to reliability inputs but no pv_production_factor_series provided")
        end
    end
    if microgrid_only && !Bool(get(r2, :pv_migrogrid_upgraded, false))
        pv_kw_ac_hourly = zero_array
    end

    if :battery_size_kw in keys(r2)
        if !microgrid_only || Bool(get(r2, :storage_microgrid_upgraded, false))
            if :battery_starting_soc_series_fraction in keys(r2)
                init_soc = r2[:battery_starting_soc_series_fraction]
            else
                @warn("No battery soc series provided to reliability inputs. Assuming battery fully charged at start of outage.")
                init_soc = ones(length(r2[:net_critical_loads_kw]))
            end
            r2[:battery_starting_soc_kwh] = init_soc .* r2[:battery_size_kwh]
            #Only subtracts PV generation if there is also a battery
            r2[:net_critical_loads_kw] .-= pv_kw_ac_hourly
            if !haskey(r2, :battery_size_kwh)
                push!(invalid_args, "Battery kW provided to reliability inputs but no kWh provided.")
            end
        end
    end

    if length(invalid_args) > 0
        error("Invalid argument values: $(invalid_args)")
    end

    return r2
end
"""
    return_backup_reliability(; critical_loads_kw::Vector, generator_operational_availability::Real = 0.9998, generator_failure_to_start::Real = 0.0066, 
        generator_failure_to_run::Real = 0.00157, num_generators::Int = 1, generator_size_kw::Real = 0.0, num_battery_bins::Int = 100, max_outage_duration::Int = 96,
        battery_size_kw::Real = 0.0, battery_size_kwh::Real = 0.0, battery_charge_efficiency::Real = 0.948, battery_discharge_efficiency::Real = 0.948)::Array

Return an array of backup reliability calculations. Inputs can be unpacked from backup_reliability_inputs() dictionary
# Arguments
-net_critical_loads_kw::Vector                                                      vector of net critical loads                     
-generator_operational_availability::Union{Real, Vector{<:Real}}      = 0.9998        Fraction of year generators not down for maintenance
-generator_failure_to_start::Union{Real, Vector{<:Real}}                        = 0.0066        Chance of generator starting given outage
-generator_failure_to_run::Union{Real, Vector{<:Real}}                = 0.00157       Chance of generator failing in each hour of outage
-num_generators::Union{Int, Vector{Int}}                            = 1             Number of generators
-generator_size_kw::Union{Real, Vector{<:Real}}                       = 0.0           Backup generator capacity
-num_battery_bins::Int              = 100          Internal value for modeling battery
-max_outage_duration::Int           = 96           Maximum outage hour modeled
-battery_size_kw::Real              = 0.0          Battery kW of power capacity
-battery_size_kwh::Real             = 0.0          Battery kWh of energy capacity
-battery_charge_efficiency::Real    = 0.948        Efficiency of charging battery
-battery_discharge_efficiency::Real = 0.948        Efficiency of discharging battery
```
"""
function return_backup_reliability(; 
    net_critical_loads_kw::Vector, 
    battery_starting_soc_kwh::Array = [],  
    generator_operational_availability::Union{Real, Vector{<:Real}} = 0.9998, 
    generator_failure_to_start::Union{Real, Vector{<:Real}}  = 0.0066, 
    generator_failure_to_run::Union{Real, Vector{<:Real}}  = 0.00157, 
    num_generators::Union{Int, Vector{Int}} = 1, 
    generator_size_kw::Union{Real, Vector{<:Real}} = 0.0, 
    num_battery_bins::Int = 101,
    max_outage_duration::Int = 96,
    battery_size_kw::Real = 0.0,
    battery_size_kwh::Real = 0.0,
    battery_charge_efficiency::Real = 0.948, 
    battery_discharge_efficiency::Real = 0.948,
    kwargs...)::Array
 
    total_gen_cap = sum(generator_size_kw)
    #No reliability calculations if no outage duration
    if max_outage_duration == 0
        return []
    
    elseif battery_size_kw < 0.1
        return [
            survival_gen_only(
                net_critical_loads_kw=net_critical_loads_kw, 
                generator_operational_availability=generator_operational_availability, 
                generator_failure_to_start=generator_failure_to_start, 
                generator_failure_to_run=generator_failure_to_run, 
                num_generators=num_generators, 
                generator_size_kw=generator_size_kw, 
                max_duration=max_outage_duration, 
                marginal_survival = true
                ),
            survival_gen_only(
                net_critical_loads_kw=net_critical_loads_kw,
                generator_operational_availability=generator_operational_availability, 
                generator_failure_to_start=generator_failure_to_start, 
                generator_failure_to_run=generator_failure_to_run, 
                num_generators=num_generators, 
                generator_size_kw=generator_size_kw, max_duration=max_outage_duration, marginal_survival = false)]

    else
        return [
            survival_with_battery(
                net_critical_loads_kw=net_critical_loads_kw, 
                battery_starting_soc_kwh=battery_starting_soc_kwh, 
                generator_operational_availability=generator_operational_availability,
                generator_failure_to_start=generator_failure_to_start, 
                generator_failure_to_run=generator_failure_to_run,
                num_generators=num_generators,
                generator_size_kw=generator_size_kw, 
                battery_size_kw=battery_size_kw,
                battery_size_kwh=battery_size_kwh,
                num_battery_bins=num_battery_bins,
                max_outage_duration=max_outage_duration, 
                battery_charge_efficiency=battery_charge_efficiency,
                battery_discharge_efficiency=battery_discharge_efficiency,
                marginal_survival = true
            ),
            survival_with_battery(
                net_critical_loads_kw=net_critical_loads_kw,
                battery_starting_soc_kwh=battery_starting_soc_kwh, 
                generator_operational_availability=generator_operational_availability, 
                generator_failure_to_start=generator_failure_to_start, 
                generator_failure_to_run=generator_failure_to_run,
                num_generators=num_generators,
                generator_size_kw=generator_size_kw, 
                battery_size_kw=battery_size_kw,
                battery_size_kwh=battery_size_kwh,
                num_battery_bins=num_battery_bins,
                max_outage_duration=max_outage_duration, 
                battery_charge_efficiency=battery_charge_efficiency,
                battery_discharge_efficiency=battery_discharge_efficiency,
                marginal_survival = false
            )]

    end
end

"""
process_reliability_results(results::Array)::Dict

Return dictionary of processed backup reliability results.

# Arguments
- `results::Array`: results from function return_backup_reliability. 
"""
function process_reliability_results(results::Array)::Dict
    if isempty(results) 
        return Dict()
    else
        marginal_results = round.(results[1], digits=6)
        cumulative_results = round.(results[2], digits=6)
        marginal_duration_means = round.(vec(mean(marginal_results, dims = 1)), digits=6)
        marginal_duration_mins = round.(vec(minimum(marginal_results, dims = 1)), digits=6)
        marginal_final_resilience = round.(marginal_results[:, end], digits=6)
        cumulative_duration_means = round.(vec(mean(cumulative_results, dims = 1)), digits=6)
        cumulative_duration_mins = round.(vec(minimum(cumulative_results, dims = 1)), digits=6)
        cumulative_final_resilience = round.(cumulative_results[:, end], digits=6)
        cumulative_final_resilience_mean = round(mean(cumulative_final_resilience), digits=6)
        return Dict(
            "mean_marginal_survival_by_duration"    => marginal_duration_means,
            "min_marginal_survival_by_duration"     => marginal_duration_mins,
            "marginal_outage_survival_final_time_step"   => marginal_final_resilience,
            "mean_cumulative_survival_by_duration"  => cumulative_duration_means,
            "min_cumulative_survival_by_duration"   => cumulative_duration_mins,
            "cumulative_outage_survival_final_time_step" => cumulative_final_resilience,
            "mean_cumulative_outage_survival_final_time_step" => cumulative_final_resilience_mean
        )
    end
end


"""
	backup_reliability(d::Dict, p::REoptInputs, r::Dict)

Return dictionary of backup reliability results.

# Arguments
- `d::Dict`: REopt results dictionary. 
- `p::REoptInputs`: REopt Inputs Struct.
- `r::Dict`: Dictionary of inputs for reliability calculations. If r not included then uses all defaults. values read from dictionary:
    -generator_operational_availability::Real = 0.9998 (Fraction of year generators not down for maintenance)
    -generator_failure_to_start::Real = 0.0066 (Chance of generator starting given outage)
    -generator_failure_to_run::Real = 0.00157 (Chance of generator failing in each hour of outage)
    -num_generators::Int = 1  (Number of generators. Will be determined by code if set to 0 and gen capacity > 0.1)
    -generator_size_kw::Real = 0.0 (Backup generator capacity. Will be determined by REopt optimization if set less than 0.1)
    -num_battery_bins::Int = 100 (Internal value for discretely modeling battery state of charge)
    -max_outage_duration::Int = 96 (Maximum outage hour modeled)
    -microgrid_only::Bool = false (determines how generator, PV, and battery act during islanded mode)

"""
function backup_reliability(d::Dict, p::REoptInputs, r::Dict)
    reliability_inputs = backup_reliability_reopt_inputs(d=d, p=p, r=r)
	results = return_backup_reliability(; reliability_inputs... )
	process_reliability_results(results)
end


"""
	backup_reliability(r::Dict)

Return dictionary of backup reliability results.

# Arguments
- `r::Dict`: Dictionary of inputs for reliability calculations. If r not included then uses all defaults. values read from dictionary:
inputs of r:
-critical_loads_kw::Array                   Critical loads per time step. (Required input)
-microgrid_only::Bool                       Boolean to check if only microgrid runs during grid outage (defaults to false)
-chp_size_kw::Real                         CHP capacity. 
-pv_size_kw::Real                           Size of PV System
-pv_production_factor_series::Array         PV production factor per time step (required if pv_size_kw in dictionary)
-pv_migrogrid_upgraded::Bool                If true then PV runs during outage if microgrid_only = TRUE (defaults to false)
-battery_size_kw::Real                      Battery capacity. If no battery installed then PV disconnects from system during outage
-battery_size_kwh::Real                     Battery energy storage capacity
-charge_efficiency::Real                    Battery charge efficiency
-discharge_efficiency::Real                 Battery discharge efficiency
-battery_starting_soc_series_fraction::Array     Battery percent state of charge time series during normal grid-connected usage
-generator_failure_to_start::Real = 0.0066  Chance of generator starting given outage
-generator_failure_to_run::Real = 0.00157   Chance of generator failing in each hour of outage
-num_generators::Int = 1                    Number of generators. Will be determined by code if set to 0 and gen capacity > 0.1
-generator_size_kw::Real = 0.0              Backup generator capacity. Will be determined by REopt optimization if set less than 0.1
-num_battery_bins::Int = 100                Internal value for discretely modeling battery state of charge
-max_outage_duration::Int = 96              Maximum outage hour modeled

"""
function backup_reliability(r::Dict)
    reliability_inputs = backup_reliability_inputs(r=r)
	results = return_backup_reliability(; reliability_inputs... )
	process_reliability_results(results)
end