"""
Outline:
1. Construct LDF.Inputs from openDSS file, load dict
2. Add power flow constraints to m, 
    - set Pⱼ's = -1 * (dvGridPurchase_j - dvProductionToGrid_j)
3. solve model
"""
# TODO add complementary constraint to UL for dvProductionToGrid_ and dvGridPurchase_ (don't want it in LL s.t. it stays linear)


function LDF.build_ldf!(m::JuMP.AbstractModel, p::LDF.Inputs, ps::Array{REoptInputs{Scenario}, 1};
        make_import_export_complementary::Bool=true
    )
    LDF.add_variables(m, p)
    add_expressions(m, ps)
    LDF.constrain_power_balance(m, p)
    LDF.constrain_substation_voltage(m, p)
    LDF.constrain_KVL(m, p)
    LDF.constrain_loads(m, p, ps)
    LDF.constrain_bounds(m, p)

    if make_import_export_complementary
        add_complementary_constraints(m, ps)
    end
end


function add_expressions(m::JuMP.AbstractModel, ps::Array{REoptInputs{Scenario}, 1})
    for p in ps
        _n = string("_", p.s.site.node)
        m[Symbol("TotalExport"*_n)] = @expression(m, [ts in p.time_steps],
            sum(
                m[Symbol("dvProductionToGrid"*_n)][t,u,ts] 
                for t in p.techs.elec, u in p.export_bins_by_tech[t]
            )
            + sum(m[Symbol("dvStorageToGrid"*_n)][b,ts] for b in p.s.storage.types.all )# added this line to include battery export in the total export

            
        )
    end
end


function add_complementary_constraints(m::JuMP.AbstractModel, ps::Array{REoptInputs{Scenario}, 1})
    for p in ps
        _n = string("_", p.s.site.node)
        for (i, e) in zip(m[Symbol("dvGridPurchase"*_n)], m[Symbol("TotalExport"*_n)])
            @constraint(m,
                [i, e] in MOI.SOS1([1.0, 2.0])
            )
        end
    end
end


function LDF.constrain_loads(m::JuMP.AbstractModel, p::LDF.Inputs, ps::Array{REoptInputs{Scenario}, 1})
    reopt_nodes =  [p.s.site.node for p in ps] 
    print("\n Debugging: PRINTING DATA FROM THE CONSTRAIN_LOADS FUNCTION")
    print("\n reopt_nodes:") 
    print(reopt_nodes) 
    Pⱼ = m[:Pⱼ]
    Qⱼ = m[:Qⱼ]
    # positive values are injections

    for j in p.busses
        if j in keys(p.Pload)
            if parse(Int, j) in reopt_nodes
                print() 
                print(Int)
                @constraint(m, [t in 1:p.Ntimesteps],
                    Pⱼ[j,t] == 1e3/p.Sbase * (  # 1e3 b/c REopt values in kW
                        m[Symbol("TotalExport_" * j)][t]
                        - m[Symbol("dvGridPurchase_" * j)][t]
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
            if parse(Int, j) in reopt_nodes
                @constraint(m, [t in 1:p.Ntimesteps],
                    Qⱼ[j,t] == 1e3/p.Sbase * p.pf * (  # 1e3 b/c REopt values in kW
                    m[Symbol("TotalExport_" * j)][t]
                        - m[Symbol("dvGridPurchase_" * j)][t]
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

# TODO add LDF results (here and in LDF package)

function run_reopt(m::JuMP.AbstractModel, p::REoptInputs, ldf::LDF.Inputs)

end