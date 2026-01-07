# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

"""
    LoadUncertainty

Defines uncertainty parameters for electric load at each timestep.

# Fields
- `enabled::Bool`: Whether uncertainty is enabled
- `deviation_fractions::Array{<:Real,1}`: Array of fractional deviations from nominal (e.g., [-0.10, 0.0, 0.10] for -10%, nominal, +10%)
- `deviation_probabilities::Array{<:Real,1}`: Probability of each deviation scenario (must sum to 1.0)

# Example
```julia
LoadUncertainty(
    enabled=true,
    deviation_fractions=[-0.10, 0.0, 0.10],
    deviation_probabilities=[0.25, 0.50, 0.25]
)
```
"""
struct LoadUncertainty
    enabled::Bool
    deviation_fractions::Array{<:Real,1}
    deviation_probabilities::Array{<:Real,1}
    
    function LoadUncertainty(;
        enabled::Bool = false,
        deviation_fractions::Array{<:Real,1} = [-0.1, 0.0, 0.1],
        deviation_probabilities::Array{<:Real,1} = [0.25, 0.50, 0.25]
    )
        # Validate probabilities sum to 1
        if abs(sum(deviation_probabilities) - 1.0) > 1e-6
            throw(@error("LoadUncertainty deviation_probabilities must sum to 1.0"))
        end
        # Validate array lengths match
        if length(deviation_fractions) != length(deviation_probabilities)
            throw(@error("LoadUncertainty deviation_fractions and deviation_probabilities must have the same length"))
        end
        # Validate deviation fractions are reasonable
        if any(abs.(deviation_fractions) .> 1.0)
            throw(@error("LoadUncertainty deviation_fractions must be between -1 and 1"))
        end
        new(enabled, deviation_fractions, deviation_probabilities)
    end
end


"""
    ProductionUncertainty

Defines uncertainty parameters for renewable production factors.

# Fields
- `enabled::Bool`: Whether uncertainty is enabled
- `deviation_fractions::Array{<:Real,1}`: Array of fractional deviations from nominal (e.g., [-0.10, 0.0, 0.10] for -10%, nominal, +10%)
- `deviation_probabilities::Array{<:Real,1}`: Probability of each deviation scenario (must sum to 1.0)

# Example
```julia
ProductionUncertainty(
    enabled=true,
    deviation_fractions=[-0.10, 0.0, 0.10],
    deviation_probabilities=[0.25, 0.50, 0.25]
)
```
"""
struct ProductionUncertainty
    enabled::Bool
    deviation_fractions::Array{<:Real,1}
    deviation_probabilities::Array{<:Real,1}
    
    function ProductionUncertainty(;
        enabled::Bool = false,
        deviation_fractions::Array{<:Real,1} = [-0.1, 0.0, 0.1],
        deviation_probabilities::Array{<:Real,1} = [0.25, 0.50, 0.25]
    )
        if abs(sum(deviation_probabilities) - 1.0) > 1e-6
            throw(@error("ProductionUncertainty deviation_probabilities must sum to 1.0"))
        end
        if length(deviation_fractions) != length(deviation_probabilities)
            throw(@error("ProductionUncertainty deviation_fractions and deviation_probabilities must have the same length"))
        end
        if any(abs.(deviation_fractions) .> 1.0)
            throw(@error("ProductionUncertainty deviation_fractions must be between -1 and 1"))
        end
        new(enabled, deviation_fractions, deviation_probabilities)
    end
end


"""
    generate_load_scenarios(nominal_loads_kw, uncertainty)

Generate load scenarios based on uncertainty specification.

# Arguments
- `nominal_loads_kw::Array{<:Real, 1}`: Nominal load profile
- `uncertainty::LoadUncertainty`: Uncertainty specification

# Returns
- `scenarios::Dict{Int, Array{Float64, 1}}`: Dictionary mapping scenario ID to load profile
- `probabilities::Array{Float64, 1}`: Probability of each scenario

# Example
```julia
scenarios, probs = generate_load_scenarios([100.0, 150.0, 200.0], LoadUncertainty(enabled=true))
```
"""
function generate_load_scenarios(
    nominal_loads_kw::Array{<:Real, 1},
    uncertainty::LoadUncertainty
)
    if !uncertainty.enabled
        # Single scenario (deterministic)
        return Dict{Int, Vector{Float64}}(1 => Float64.(nominal_loads_kw)), [1.0]
    end
    
    scenarios = Dict{Int, Vector{Float64}}()
    probabilities = Float64[]
    
    # Generate scenario for each deviation
    for (idx, (deviation, prob)) in enumerate(zip(uncertainty.deviation_fractions, uncertainty.deviation_probabilities))
        scenarios[idx] = Float64.(nominal_loads_kw .* (1.0 + deviation))
        push!(probabilities, prob)
    end
    
    return scenarios, probabilities
end


"""
    generate_production_scenarios(nominal_production_factor, uncertainty, renewable_techs)

Generate production factor scenarios for renewable technologies.

# Arguments
- `nominal_production_factor::Dict{String, Array{Float64, 1}}`: Nominal production factors by tech
- `uncertainty::ProductionUncertainty`: Uncertainty specification
- `renewable_techs::Array{String, 1}`: Technologies to apply uncertainty to (e.g., PV, Wind)

# Returns
- `scenarios::Dict{Int, Dict{String, Array{Float64, 1}}}`: Dictionary mapping scenario ID to production factors by tech
- `probabilities::Array{Float64, 1}`: Probability of each scenario

# Example
```julia
pf = Dict("PV" => [0.5, 0.6, 0.7])
scenarios, probs = generate_production_scenarios(pf, ProductionUncertainty(enabled=true), ["PV"])
```
"""
function generate_production_scenarios(
    nominal_production_factor::Dict{String, Array{Float64, 1}},
    uncertainty::ProductionUncertainty,
    renewable_techs::Array{String, 1}
)
    if !uncertainty.enabled
        return Dict{Int, Dict{String, Vector{Float64}}}(1 => nominal_production_factor), [1.0]
    end
    
    scenarios = Dict{Int, Dict{String, Vector{Float64}}}()
    probabilities = Float64[]
    
    # Generate scenario for each deviation
    for (idx, (deviation, prob)) in enumerate(zip(uncertainty.deviation_fractions, uncertainty.deviation_probabilities))
        scenarios[idx] = Dict{String, Vector{Float64}}()
        
        # Copy all tech production factors
        for (tech, factors) in nominal_production_factor
            if tech in renewable_techs
                # Apply uncertainty
                scenarios[idx][tech] = Float64.(factors .* (1.0 + deviation))
            else
                # No uncertainty for this tech
                scenarios[idx][tech] = Float64.(copy(factors))
            end
        end
        
        push!(probabilities, prob)
    end
    
    return scenarios, probabilities
end


"""
    combine_load_production_scenarios(load_scenarios, load_probs, prod_scenarios, prod_probs)

Combine independent load and production scenarios into joint scenarios.
Assumes independence between load and production uncertainty.

# Arguments
- `load_scenarios::Dict{Int, Array{Float64, 1}}`: Load scenarios
- `load_probs::Array{Float64, 1}`: Load scenario probabilities
- `prod_scenarios::Dict{Int, Dict{String, Array{Float64, 1}}}`: Production scenarios
- `prod_probs::Array{Float64, 1}`: Production scenario probabilities

# Returns
- `combined_loads::Dict{Int, Array{Float64, 1}}`: Combined load scenarios
- `combined_prods::Dict{Int, Dict{String, Array{Float64, 1}}}`: Combined production scenarios
- `combined_probs::Array{Float64, 1}`: Combined scenario probabilities

# Note
If both load and production uncertainty are enabled, this creates 9 scenarios (3 load × 3 production).
"""
function combine_load_production_scenarios(
    load_scenarios::Dict{Int, Array{Float64, 1}},
    load_probs::Array{Float64, 1},
    prod_scenarios::Dict{Int, Dict{String, Array{Float64, 1}}},
    prod_probs::Array{Float64, 1}
)
    n_load = length(load_scenarios)
    n_prod = length(prod_scenarios)
    
    combined_loads = Dict{Int, Array{Float64, 1}}()
    combined_prods = Dict{Int, Dict{String, Array{Float64, 1}}}()
    combined_probs = Float64[]
    
    scenario_id = 1
    for i in 1:n_load
        for j in 1:n_prod
            combined_loads[scenario_id] = load_scenarios[i]
            combined_prods[scenario_id] = prod_scenarios[j]
            push!(combined_probs, load_probs[i] * prod_probs[j])
            scenario_id += 1
        end
    end
    
    return combined_loads, combined_prods, combined_probs
end
