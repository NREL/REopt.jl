
# Additional code for interfacing between the power_flow.jl and other REopt code

function build_power_flow!(m::JuMP.AbstractModel, p::PowerFlowInputs, ps::Array{REoptInputs{Scenario}, 1};
        make_import_export_complementary::Bool=true
    )
    power_flow_add_variables(m, p)
    add_expressions(m, ps)
    constrain_power_balance(m, p)
    constrain_substation_voltage(m, p)
    create_line_variables(m, p)
    constrain_loads(m, p, ps)
    # Note: the constrain_KVL(m, p) function is called in the microgrid.jl file
    if make_import_export_complementary
        add_complementary_constraints(m, ps)
    end
end

#2. Add power flow constraints to m, 
#    - set Pⱼ's = -1 * (dvGridPurchase_j - dvProductionToGrid_j)
function add_expressions(m::JuMP.AbstractModel, ps::Array{REoptInputs{Scenario}, 1})
    for p in ps
        _n = string("_", p.s.site.node)
        if string(p.s.site.node) != p.s.settings.facilitymeter_node
            print("\n Applying total export equation for node $(p.s.site.node)")
            m[Symbol("TotalExport"*_n)] = @expression(m, [ts in p.time_steps],
                sum(
                    m[Symbol("dvProductionToGrid"*_n)][t,u,ts] 
                    for t in p.techs.elec, u in p.export_bins_by_tech[t]
                )
                + sum(m[Symbol("dvStorageToGrid"*_n)][b,ts] for b in p.s.storage.types.all )# added this line to include battery export in the total export
            )
        else
            # set the total node export to 0 for the facility meter grid, because that node has no techs
                # also, for that node, the dvProductionToGrid is used for the grid export benefits and set to the powerflow of the substation line when flow on that line is negative
            print("\n Setting the total export for node $(p.s.site.node) to zero. This node is the facility meter node.")
            
            dv = "TotalExport_"*p.s.settings.facilitymeter_node
            m[Symbol(dv)] = @variable(m, [p.time_steps], base_name=dv, lower_bound =0)

            @constraint(m, [t in p.time_steps], m[Symbol("TotalExport_"*p.s.settings.facilitymeter_node)][t] == 0)

        end
    end
end

# TODO add complementary constraint to UL for dvProductionToGrid_ and dvGridPurchase_ (don't want it in LL s.t. it stays linear)
function add_complementary_constraints(m::JuMP.AbstractModel, ps::Array{REoptInputs{Scenario}, 1})
    for p in ps
        _n = string("_", p.s.site.node)
        #if string(p.s.site.node) != "15" # the complementary constraint has an affect when it is applied to the facility meter node
            #print("\n Adding the complementary constraint to node $(p.s.site.node)")
            for (i, e) in zip(m[Symbol("dvGridPurchase"*_n)], m[Symbol("TotalExport"*_n)])
                @constraint(m,
                    [i, e] in MOI.SOS1([1.0, 2.0])
                )
            end
        #else
        #    print("\n Not adding the complementary constraint to the facility meter node, node $(p.s.site.node)")
        #end
    end
end


function constrain_loads(m::JuMP.AbstractModel, p::PowerFlowInputs, ps::Array{REoptInputs{Scenario}, 1})
    
    Pⱼ = m[:Pⱼ]
    Qⱼ = m[:Qⱼ]
    
    reopt_nodes =  [p.s.site.node for p in ps] 
    print("\n The REopt nodes being applied in extend.jl are: $(reopt_nodes) \n") 
    
    # Note: positive values are injections
    #print("\n p.Pload is: $(p.Pload) ")
    
    for j in p.busses
        if j in keys(p.Pload)
            #print("\n the j variable is: $(j) ")
            if parse(Int, j) in reopt_nodes
                if j != "15" 
                    #print("\n j is not 15")               
                    @constraint(m, [t in 1:p.Ntimesteps],
                        Pⱼ[j,t] == 1e3/p.Sbase * (  # 1e3 b/c REopt values in kW
                            m[Symbol("TotalExport_" * j)][t]
                            - m[Symbol("dvGridPurchase_" * j)][t]
                        )
                    )
                else
                    print("\n j is 15 and the j variable is: $(j)")
                    @constraint(m, [t in 1:p.Ntimesteps], Pⱼ["15",t] == 0)
                end
            else
                # Power balance for nodes that have loads defined through ldf, but not in the REopt inputs
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
                if j != "15"
                    #print("\n (reactive power) j is not 15") 
                    @constraint(m, [t in 1:p.Ntimesteps],
                        Qⱼ[j,t] == 1e3/p.Sbase * p.pf * (  # 1e3 b/c REopt values in kW
                        m[Symbol("TotalExport_" * j)][t]
                            - m[Symbol("dvGridPurchase_" * j)][t]
                        )
                    )
                else
                    print("\n (reactive power) j is 15 and the j variable is: $(j)")
                    @constraint(m, [t in 1:p.Ntimesteps], Qⱼ["15",t] == 0)
                end
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
    
    # Constrain loads on the transformers
    P = m[:Pᵢⱼ] 
    Q = m[:Qᵢⱼ]
    all_transformers = []
    # Define decision variable for the transformer maximum kVa
    for i in keys(p.transformers)
        if p.transformers[i]["Transformer Side"] == "downstream"
            push!(all_transformers, i)
        end
    end
    print("\n The all_transformers variable is: ")
    print(all_transformers)
    @variable(m, transformer_max_kva[all_transformers] >= 0)

    # Apply the transformer max kva to the constraints
    for i in keys(p.transformers)
        if p.transformers[i]["Transformer Side"] == "downstream"           
                DirectlyUpstreamNode = i_to_j(i, p)  
                transformer_internal_line = string(DirectlyUpstreamNode[1])*"-"*string(i)
                @constraint(m, [T in 1:p.Ntimesteps], P[transformer_internal_line, T] + Q[transformer_internal_line, T] <= ((m[:transformer_max_kva][i]*1000)/p.Sbase))
                @constraint(m, [T in 1:p.Ntimesteps], P[transformer_internal_line, T] + Q[transformer_internal_line, T] >= -((m[:transformer_max_kva][i]*1000)/p.Sbase))
        end
    end
end

