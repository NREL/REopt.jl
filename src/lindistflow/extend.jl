"""
    LDF.build_ldf!(m::JuMP.AbstractModel, p::LDF.Inputs, ps::AbstractVector{REoptInputs{Scenario}};
        make_import_export_complementary::Bool=true
    )

Override the LinDistFlow build_ldf! method to account for REoptInputs
"""
function LDF.build_ldf!(m::JuMP.AbstractModel, p::LDF.Inputs, ps::AbstractVector{REoptInputs{Scenario}};
        make_import_export_complementary::Bool=true
    )
    LDF.add_variables(m, p)
    add_expressions(m, ps)
    LDF.constrain_power_balance(m, p)
    LDF.constrain_substation_voltage(m, p)
    LDF.constrain_KVL(m, p)
    LDF.constrain_loads(m, p, ps)

    if make_import_export_complementary
        add_complementary_constraints(m, ps)
    end
end


"""
    add_expressions(m::JuMP.AbstractModel, ps::AbstractVector{REoptInputs{Scenario}})

Add the TotalExport_n expressions for use in defining LinDistFlow net injections
"""
function add_expressions(m::JuMP.AbstractModel, ps::AbstractVector{REoptInputs{Scenario}})
    for p in ps
        _n = string("_", p.s.site.node)
        m[Symbol("TotalExport"*_n)] = @expression(m, [t in p.time_steps],
            sum(
                m[Symbol("dvProductionToGrid"*_n)][t,u,ts] 
                for t in p.techs.elec, u in p.export_bins_by_tech[t]
            )
        )
    end
end


"""
    add_complementary_constraints(m::JuMP.AbstractModel, ps::AbstractVector{REoptInputs{Scenario}})

Constrain one or both of `dvGridPurchase_n` and `TotalExport_n` to be zero.
"""
function add_complementary_constraints(m::JuMP.AbstractModel, ps::AbstractVector{REoptInputs{Scenario}})
    for p in ps
        _n = string("_", p.s.site.node)
        for (i, e) in zip(m[Symbol("dvGridPurchase"*_n)], m[Symbol("TotalExport"*_n)])
            @constraint(m,
                [i, e] in MOI.SOS1([1.0, 2.0])
            )
        end
    end
end


"""
    LDF.constrain_loads(m::JuMP.AbstractModel, p::LDF.Inputs, ps::AbstractVector{REoptInputs{Scenario}})

Override the `LinDistFlow.constrain_loads` method to set REopt decisions as net load injections
"""
function LDF.constrain_loads(m::JuMP.AbstractModel, p::LDF.Inputs, ps::AbstractVector{REoptInputs{Scenario}})
    reopt_nodes = [p.s.site.node for p in ps]

    Pj = m[:Pj]
    Qj = m[:Qj]
    # positive values are injections

    for j in p.busses
        if j in keys(p.Pload)
            if parse(Int, j) in reopt_nodes
                @constraint(m, [t in 1:p.Ntimesteps],
                    Pj[j,t] == 1e3/p.Sbase * (  # 1e3 b/c REopt values in kW
                        m[Symbol("TotalExport_" * j)][t]
                        - m[Symbol("dvGridPurchase_" * j)][t]
                    )
                )
            else
                @constraint(m, [t in 1:p.Ntimesteps],
                    Pj[j,t] == -p.Pload[j][t]
                )
            end
        elseif j != p.substation_bus
            @constraint(m, [t in 1:p.Ntimesteps],
                Pj[j,t] == 0
            )
        end
        
        if j in keys(p.Qload)
            if parse(Int, j) in reopt_nodes
                @constraint(m, [t in 1:p.Ntimesteps],
                    Qj[j,t] == 1e3/p.Sbase * p.pf * (  # 1e3 b/c REopt values in kW
                    m[Symbol("TotalExport_" * j)][t]
                        - m[Symbol("dvGridPurchase_" * j)][t]
                    )
                )
            else
                @constraint(m, [t in 1:p.Ntimesteps],
                    Qj[j,t] == -p.Qload[j][t]
                )
            end
        elseif j != p.substation_bus
            @constraint(m, [t in 1:p.Ntimesteps],
                Qj[j,t] == 0
            )
        end
    end
    nothing
end


# function run_reopt(m::JuMP.AbstractModel, p::REoptInputs, ldf::LDF.Inputs)
# TODO add LDF results (here and in LDF package)
# end
