"""
Outline:
1. Construct LDF.Inputs from openDSS file, load dict
2. Add power flow constraints to m, 
    - set Pⱼ's = -1 * (dvGridPurchase_j - dvWHLexport_j - dvNEMexport_j)
3. solve model
"""

function LDF.build_ldf!(m::JuMP.AbstractModel, p::Inputs, reoptnodes::Array{String, 1})

    LDF.add_variables(m, p)
    LDF.constrain_power_balance(m, p)
    LDF.constrain_substation_voltage(m, p)
    LDF.constrain_KVL(m, p)
    LDF.constrain_loads(m, p, reoptnodes)
    LDF.constrain_bounds(m, p)

end

function LDF.constrain_loads(m::JuMP.AbstractModel, p::LDF.Inputs, reoptnodes::Array{String, 1})

    Pⱼ = m[:Pⱼ]
    Qⱼ = m[:Qⱼ]

    for j in p.busses
        if j in keys(p.Pload)
            if parse(Int, j) in reoptnodes
                j_int = parse(Int, j)
                i = indexin([j_int], reoptnodes)[1]

                @constraint(m, [t in 1:p.Ntimesteps],
                    Pⱼ[j,t] == 1e3/p.Sbase * (  # 1e3 b/c REopt values in kW
                        - m[Symbol("dvNetGridDraw_" * j)][t]
                    )
                )
            else
                @constraint(m, [t in 1:p.Ntimesteps],
                    Pⱼ[j,t] == -p.Pload[j][t]
                )
            end
        elseif j != p.substation_bus
            @constraint(m, [t in 1:p.Ntimesteps],
                Pⱼ[j,t] == 0
            )
        end
        
        if j in keys(p.Qload)
            if j in reoptnodes
                @constraint(m, [t in 1:p.Ntimesteps],
                    Qⱼ[j,t] == 1e3/p.Sbase * (  # 1e3 b/c REopt values in kW
                        - m[Symbol("dvNetGridDraw_" * j)][t] * p.pf
                    )
                )
            else
                @constraint(m, [t in 1:p.Ntimesteps],
                    Qⱼ[j,t] == -p.Qload[j][t]
                )
            end
        elseif j != p.substation_bus
            @constraint(m, [t in 1:p.Ntimesteps],
                Qⱼ[j,t] == 0
            )
        end
    end
    p.Nequality_cons += 2 * (p.Nnodes - 1) * p.Ntimesteps
end


function run_reopt(m::JuMP.AbstractModel, p::REoptInputs, ldf::LDF.Inputs)

end