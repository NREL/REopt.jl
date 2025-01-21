#=
Acknowledgement: This code is based on code from the LinDistFlow.jl package
=#

"""
mutable struct PowerFlowInputs
"""
mutable struct PowerFlowInputs
edges::Array{Tuple, 1}
linecodes::Array{String, 1}
linelengths::Array{Float64, 1}
linenormamps::Array{Float64, 1}
busses::Array{String}
substation_bus::String
Pload::Dict{String, AbstractArray{Real, 1}}
Qload::Dict{String, AbstractArray{Real, 1}}
Sbase::Real
Vbase::Real
Ibase::Real
Zdict::Dict{String, Dict{String, Any}}
v0::Real
v_lolim::Real
v_uplim::Real
Zbase::Real
Ntimesteps::Int
Nequality_cons::Int
Nlte_cons::Int
pf::Float64
Nnodes::Int
P_up_bound::Float64
Q_up_bound::Float64
P_lo_bound::Float64
Q_lo_bound::Float64
transformers::Dict
regulators::Dict
end 


function PowerFlowInputs(
edges::Array{Tuple}, 
linecodes::Array{String}, 
linelengths::Array{Float64},
linenormamps::Array{Float64},
substation_bus::String;
Pload, 
Qload, 
Sbase=1, 
Vbase=1, 
Zdict, 
v0, 
v_lolim=0.95, 
v_uplim=1.05,
Ntimesteps=1, 
Nequality_cons=0, 
Nlte_cons=0,
P_up_bound=1e4,
Q_up_bound=1e4,
P_lo_bound=-1e4,
Q_lo_bound=-1e4,
transformers=Dict(),
regulators=Dict()
)
Ibase = Sbase / (Vbase * sqrt(3))
# Ibase^2 should be used to recover amperage from lᵢⱼ ?
Zbase = Vbase / (Ibase * sqrt(3))
@info "Zbase: ", Zbase
busses = String[]
for t in edges
    push!(busses, t[1])
    push!(busses, t[2])
end
busses = unique(busses)

PowerFlowInputs(
    edges,
    linecodes,
    linelengths,
    linenormamps,
    busses,
    substation_bus,
    Dict(k => v/Sbase for (k,v) in Pload),
    Dict(k => v/Sbase for (k,v) in Qload),
    Sbase,
    Vbase,
    Ibase,
    Zdict,
    v0,
    v_lolim, 
    v_uplim,
    Zbase,
    Ntimesteps,
    Nequality_cons,
    Nlte_cons,
    0.1,  # power factor
    length(busses),  # Nnodes
    P_up_bound,
    Q_up_bound,
    P_lo_bound,
    Q_lo_bound,
    transformers,
    regulators
)
end

"""
Inputs(
    dsslinesfilepath::String, 
    substation_bus::String, 
    dsslinecodesfilepath::String;
    Pload::AbstractDict, 
    Qload::AbstractDict, 
    Sbase=1, 
    Vbase=1, 
    v0, 
    v_lolim=0.95, 
    v_uplim=1.05,
    Ntimesteps=1, 
    Nequality_cons=0, 
    Nlte_cons=0,
    P_up_bound,
    Q_up_bound,
    P_lo_bound,
    Q_lo_bound,
    )

Inputs constructor
"""
function PowerFlowInputs(
dsslinesfilepath::String, 
substation_bus::String, 
dsslinecodesfilepath::String;
dsstransformersfilepath = "None", 
Pload::AbstractDict, 
Qload::AbstractDict, 
Sbase=1, 
Vbase=1, 
v0, 
v_lolim=0.95, 
v_uplim=1.05,
Ntimesteps=1, 
Nequality_cons=0, 
Nlte_cons=0,
P_up_bound=1e4,
Q_up_bound=1e4,
P_lo_bound=-1e4,
Q_lo_bound=-1e4
)
edges, linecodes, linelengths, linenormamps = dss_parse_lines(dsslinesfilepath)
linecodes_dict = dss_parse_line_codes(dsslinecodesfilepath, linecodes)


if dsstransformersfilepath == "None"
    @info "No transformers or voltage regulators were input into the model"
    transformers_dict = Dict(["NoTransformer","NoTransformer"])
    regulators_dict = Dict([])
else
    @info "Transformers and/or voltage regulators have been input into the model"
    transformers_dict, regulators_dict = dss_parse_transformers(dsstransformersfilepath)
    print("\n Transformers included are: $(transformers_dict)")
    print("\n Regulators included are: $(regulators_dict)")
end 
PowerFlowInputs(
    edges,
    linecodes,
    linelengths,
    linenormamps,
    substation_bus;
    Pload=Pload, 
    Qload=Qload,
    Sbase=Sbase, 
    Vbase=Vbase, 
    Zdict=linecodes_dict, 
    v0=v0,
    v_lolim = v_lolim, 
    v_uplim = v_uplim, 
    Ntimesteps=Ntimesteps,
    Nequality_cons=Nequality_cons,
    Nlte_cons=Nlte_cons,
    P_up_bound=P_up_bound,
    Q_up_bound=Q_up_bound,
    P_lo_bound=P_lo_bound,
    Q_lo_bound=Q_lo_bound,
    transformers= transformers_dict,
    regulators = regulators_dict
)
end

function build_power_flow!(m::JuMP.AbstractModel, p::PowerFlowInputs, ps::Array{REoptInputs{Scenario}, 1};
    make_import_export_complementary::Bool=true)

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
        print("\n Adding the complementary constraint to node $(p.s.site.node)")
        for (i, e) in zip(m[Symbol("dvGridPurchase"*_n)], m[Symbol("TotalExport"*_n)])
            @constraint(m,
                [i, e] in MOI.SOS1([1.0, 2.0])
            )
        end
end
end


function constrain_loads(m::JuMP.AbstractModel, p::PowerFlowInputs, ps::Array{REoptInputs{Scenario}, 1})

Pⱼ = m[:Pⱼ]
Qⱼ = m[:Qⱼ]

reopt_nodes =  [p.s.site.node for p in ps] 

# Note: positive values are injections

for j in p.busses
    if j in keys(p.Pload)
        #print("\n Debugging: the j variable is: $(j) ")
        if parse(Int, j) in reopt_nodes
            if j != "15" 
                #print("\n Debuggin: j is not 15")               
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
            # This constraint is for the power balance for nodes that have loads defined through ldf, but not in the REopt inputs
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
                #print("\n Debuggin: (reactive power) j is not 15") 
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


function power_flow_add_variables(m, p::PowerFlowInputs)
    T = 1:p.Ntimesteps
    # bus injections
    @variables m begin
        p.P_lo_bound <= Pⱼ[p.busses, T] <= p.P_up_bound
        p.Q_lo_bound <= Qⱼ[p.busses, T] <= p.Q_up_bound
    end

    # voltage squared
    @variable(m, p.v_lolim^2 <= vsqrd[p.busses, T] <= p.v_uplim^2 ) 

    p.Nlte_cons += 6 * p.Nnodes * p.Ntimesteps
    
    ij_edges = [string(i*"-"*j) for j in p.busses for i in i_to_j(j, p)]
    Nedges = length(ij_edges)

    # line flows, power sent from i to j
    @variable(m, p.P_lo_bound <= Pᵢⱼ[ij_edges, T] <= p.P_up_bound )
    @variable(m, p.Q_lo_bound <= Qᵢⱼ[ij_edges, T] <= p.Q_up_bound )
      
    p.Nlte_cons += 4 * Nedges * p.Ntimesteps
end


function constrain_power_balance(m, p::PowerFlowInputs)
    Pⱼ = m[:Pⱼ]
    Qⱼ = m[:Qⱼ]
    Pᵢⱼ = m[:Pᵢⱼ]
    Qᵢⱼ = m[:Qᵢⱼ]
    
  
    display(print("\n  The p.busses variable is:"))
    display(print(p.busses))
    display(print("\n -----"))
    # TODO change Pⱼ and Qⱼ to expressions, make P₀ and Q₀ dv's, which will reduce # of variables
    # by (Nnodes - 1)*8760 and number of constraints by 6*(Nnodes - 1)*8760
    for j in p.busses
        if isempty(i_to_j(j, p)) && !isempty(j_to_k(j, p)) # source nodes
            pcon = @constraint(m,  [t in 1:p.Ntimesteps],
                Pⱼ[j,t] - sum( Pᵢⱼ[string(j*"-"*k), t] for k in j_to_k(j, p) ) == 0
            )
            qcon = @constraint(m, [t in 1:p.Ntimesteps],
                Qⱼ[j,t] - sum( Qᵢⱼ[string(j*"-"*k), t] for k in j_to_k(j, p) ) == 0
            )
        elseif isempty(i_to_j(j, p)) && isempty(j_to_k(j, p))  # unconnected nodes
            @warn "Bus $j has no edges, setting Pⱼ and Qⱼ to zero."
            pcon = @constraint(m, [t in 1:p.Ntimesteps],
                Pⱼ[j,t] == 0
            )
            qcon = @constraint(m, [t in 1:p.Ntimesteps],
                Qⱼ[j,t] == 0
            )
        elseif !isempty(i_to_j(j, p)) && isempty(j_to_k(j, p))  # leaf nodes
            pcon = @constraint(m, [t in 1:p.Ntimesteps],
                sum( Pᵢⱼ[string(i*"-"*j), t] for i in i_to_j(j, p) ) + Pⱼ[j, t] == 0
            )
            qcon = @constraint(m, [t in 1:p.Ntimesteps],
                sum( Qᵢⱼ[string(i*"-"*j), t] for i in i_to_j(j, p) ) + Qⱼ[j, t] == 0
            )
        else
            pcon =  @constraint(m, [t in 1:p.Ntimesteps],
                sum( Pᵢⱼ[string(i*"-"*j), t] for i in i_to_j(j, p) ) +
                Pⱼ[j,t] - sum( Pᵢⱼ[string(j*"-"*k), t] for k in j_to_k(j, p) ) == 0
            )
            qcon = @constraint(m, [t in 1:p.Ntimesteps],
                sum( Qᵢⱼ[string(i*"-"*j), t] for i in i_to_j(j, p) ) +
                Qⱼ[j,t] - sum( Qᵢⱼ[string(j*"-"*k), t] for k in j_to_k(j, p) ) == 0
            )
        end
    end
    p.Nequality_cons += 2 * p.Nnodes * p.Ntimesteps
end


function constrain_substation_voltage(m, p::PowerFlowInputs)
    # @info "constrain_substation_voltage"
    @constraint(m, con_substationV[t in 1:p.Ntimesteps],
       m[:vsqrd][p.substation_bus, t] == p.v0^2
    )
    p.Nequality_cons += p.Ntimesteps
end

function DetermineLineNominalVoltage(p::PowerFlowInputs)  # determine the nominal line voltage
    BusNominalVoltages_Summary = Dict([])
    LineNominalVoltages_Summary = Dict([])
    if p.transformers != Dict(["NoTransformer","NoTransformer"])
        print("\n  Adding line and bus voltages based on the transformer file")
        for node in p.busses
        
            if node in keys(p.transformers)
                
                BusVoltage = string(parse(Float64, p.transformers[node]["Voltage"])*1000) # convert from kV to V
                print("\n  **Bus "*string(node)*" is part of a transformer and the nominal voltage (V) is: "*string(BusVoltage))
                # Line nominal voltages
                DirectlyUpstreamNode = i_to_j(node, p) 
                LineVoltage = BusVoltage 
                line = string(DirectlyUpstreamNode[1])*"-"*string(node)
                print("\n    Line nominal voltage for line "*line*" is "*string(LineVoltage))
                LineNominalVoltages_Summary = merge!(LineNominalVoltages_Summary, Dict(line => LineVoltage))
                # Note: The lines between the two transformer nodes should be modeled as very short
            elseif node == p.substation_bus # if node is the substation, then that node takes the Vbase defined by the user
                BusVoltage = string(Float64(p.Vbase)) # this is already in volts
                print("\n  Bus "*string(node)*" is the substation, with a nominal voltage of "*string(BusVoltage))
                # there are no lines upstream of the substation in the network, so don't define a line voltage here
            else 
                UpstreamNode_vector = i_to_j(node, p) 
                UpstreamNode = UpstreamNode_vector[1]
                KeepSearchingNetwork = true
                for x in 1:length(p.busses)+1 
                    if UpstreamNode == p.substation_bus
                        # Bus nominal voltages
                        BusVoltage = string(Float64(p.Vbase)) # Vbase is already in units of volts
                        print("\n  Bus voltage at node "*string(node)*" is "*string(BusVoltage)*" note: the substation is upstream of this node")
                        # Line nominal voltage 
                        DirectlyUpstreamNode = i_to_j(node, p) 
                        LineVoltage = BusVoltage
                        line = string(DirectlyUpstreamNode[1])*"-"*string(node)
                        print("\n    Line nominal voltage for line "*line*" is "*string(LineVoltage))
                        LineNominalVoltages_Summary = merge!(LineNominalVoltages_Summary, Dict(line => LineVoltage))
                        KeepSearchingNetwork = false
                        break  # break out of the for loop 

                    elseif UpstreamNode in keys(p.transformers)
                        # Bus nominal voltages 
                        BusVoltage = string(parse(Float64,p.transformers[UpstreamNode]["Voltage"])*1000) # convert from kV to V
                        print("\n  Bus voltage at node "*string(node)* " is "*string(BusVoltage))
                        # Line nominal voltages 
                        DirectlyUpstreamNode = i_to_j(node, p) 
                        LineVoltage = BusVoltage
                        line = string(DirectlyUpstreamNode[1])*"-"*string(node)
                        print("\n    Line nominal voltage for line "*line*" is "*string(LineVoltage))
                        LineNominalVoltages_Summary = merge!(LineNominalVoltages_Summary, Dict(line => LineVoltage))
                        KeepSearchingNetwork = false
                        break  # break out of the for loop 
                    end 
                    if KeepSearchingNetwork == true
                       UpstreamNode_vector = i_to_j(UpstreamNode, p)
                       UpstreamNode = UpstreamNode_vector[1]
                    end 
                end 
            end 
            BusNominalVoltages_Summary = merge!(BusNominalVoltages_Summary, Dict(node => BusVoltage))
            
        end 
    else
        BusVoltage = string(p.Vbase)  # if there aren't any transformers, then all of the busses and lines take the base voltage at the substation 
        print("\n  There are no transformers, so the Substation nominal voltage (Vbase) will be applied to all lines and busses")
        for node in p.busses
            BusNominalVoltages_Summary = merge!(BusNominalVoltages_Summary, Dict(node => BusVoltage))
        
            if node != p.substation_bus # don't include the substation bus because there are no lines in the model beyond the substation bus
                DirectlyUpstreamNode = i_to_j(node, p)
                line = string(DirectlyUpstreamNode[1])*"-"*string(node)
                LineNominalVoltages_Summary = merge!(LineNominalVoltages_Summary, Dict(line => BusVoltage))
            end 
        end 
    end
    return LineNominalVoltages_Summary, BusNominalVoltages_Summary
end 

function create_line_variables(m, p::PowerFlowInputs)

    all_lines_temp = []
    for j in p.busses
        for i in i_to_j(j, p)
            i_j = string(i*"-"*j)
            push!(all_lines_temp, string(i_j))
        end
    end
    all_lines = unique!(all_lines_temp)

    print("\n The all_lines variable is: ")
    print(all_lines)
    
    print("\n Generating the line_max_amps variable")
    @variable(m, line_max_amps[all_lines] >= 0)

end

function constrain_KVL(m, p::PowerFlowInputs, line_upgrades_each_line, lines_for_upgrades, all_lines, Microgrid_Inputs) 
    
    w = m[:vsqrd]
    P = m[:Pᵢⱼ] 
    Q = m[:Qᵢⱼ]

    LineNominalVoltages_dict, BusNominalVoltages_dict = DetermineLineNominalVoltage(p)   
   
    if Microgrid_Inputs.Model_Line_Upgrades == true
        print("\n Generating the line_rmatrix and xmatrix variables for the upgradabe lines $(lines_for_upgrades)")
        @variable(m, line_rmatrix[lines_for_upgrades] >= 0)
        @variable(m, line_xmatrix[lines_for_upgrades] >= 0)
    end

    for j in p.busses
        for i in i_to_j(j, p)
            i_j = string(i*"-"*j)
            i_j_underscore = string(i*"_"*j)
            linelength = get_ijlinelength(i, j, p)
            
            line_code = get_ijlinecode(i,j,p) 
            LineNominalVoltage = parse(Float64,LineNominalVoltages_dict[i_j])
            rmatrix = p.Zdict[line_code]["rmatrix"]

            print("\n For line $(i_j) and linecode $(line_code): the rmatrix (without any upgrades) is $(rmatrix)") 
                        
            if (j in keys(p.regulators))
                # If there is a voltage regulator on the node, then that voltage regulator defines the per unit voltage
                @constraint(m, [t in 1:p.Ntimesteps], w[j,t] == parse(Float64, p.regulators[j]))  
                print("\n  Applying voltage regulator to node $(j) with a per unit voltage of "*string(parse(Float64, p.regulators[j]) ))
            
            elseif i_j in lines_for_upgrades && Microgrid_Inputs.Nonlinear_Solver == true
                # If the line is upgradable, account for how the rmatrix and xmatrix can change
                
                @constraint(m, m[:line_rmatrix][i_j] == sum(m[Symbol(dv)][i]*line_upgrade_options_each_line[i_j]["rmatrix"][i] for i in 1:number_of_entries))
                @constraint(m, m[:line_xmatrix][i_j] == sum(m[Symbol(dv)][i]*line_upgrade_options_each_line[i_j]["xmatrix"][i] for i in 1:number_of_entries))
                
                vcon = @constraint(m, [t in 1:p.Ntimesteps],
                    w[j,t] == w[i,t] - 2*linelength * p.Sbase * (1/(LineNominalVoltage^2)) * (m[:line_rmatrix][i_j] * P[i_j,t] +  m[:line_xmatrix][i_j] * Q[i_j,t])    )
                
                # For reference, this is the previous, uncondensed formulation:
                #rᵢⱼ = m[:line_rmatrix][i_j] * linelength * p.Sbase / (LineNominalVoltage^2)
                #xᵢⱼ = m[:line_xmatrix][i_j] * linelength * p.Sbase / (LineNominalVoltage^2)
                #vcon = @constraint(m, [t in 1:p.Ntimesteps],
                #    w[j,t] == w[i,t] - 2*(rᵢⱼ * P[i_j,t] +  xᵢⱼ * Q[i_j,t])    )
            elseif i_j in lines_for_upgrades && Microgrid_Inputs.Nonlinear_Solver == false
                # If the solver is a linear solver, then the rmatrix and xmatrix are fixed to be that of the un-upgraded line
                
                rᵢⱼ = p.Zdict[line_code]["rmatrix"] * linelength * p.Sbase / (LineNominalVoltage^2)
                xᵢⱼ = p.Zdict[line_code]["xmatrix"] * linelength * p.Sbase / (LineNominalVoltage^2)
            
                vcon = @constraint(m, [t in 1:p.Ntimesteps],
                    w[j,t] == w[i,t]
                        - 2*(rᵢⱼ * P[i_j,t] +  xᵢⱼ * Q[i_j,t])    
                )

            else
                # If the line is not upgradable (or if a linear solver is being used) and the line is not a voltage regulator, apply the standard voltage constraint
                
                linenormamps = get_ijlinenormamps(i, j, p)
                @constraint(m, m[:line_max_amps][i_j] == linenormamps)
                
                rᵢⱼ = p.Zdict[line_code]["rmatrix"] * linelength * p.Sbase / (LineNominalVoltage^2)
                xᵢⱼ = p.Zdict[line_code]["xmatrix"] * linelength * p.Sbase / (LineNominalVoltage^2)
            
                vcon = @constraint(m, [t in 1:p.Ntimesteps],
                    w[j,t] == w[i,t]
                        - 2*(rᵢⱼ * P[i_j,t] +  xᵢⱼ * Q[i_j,t])    
                )
            end

            # Apply the amperage constraints to the line:
            @constraint(m, [T in 1:p.Ntimesteps], P[i_j, T] <= ((m[:line_max_amps][i_j]*LineNominalVoltage)*(1/p.Sbase))) # Note: 1 instead of 1000 because not converting from kW 
            @constraint(m, [T in 1:p.Ntimesteps], P[i_j, T] >= -((m[:line_max_amps][i_j]*LineNominalVoltage)*(1/p.Sbase)))
            
            @constraint(m, [T in 1:p.Ntimesteps], Q[i_j, T] <= ((m[:line_max_amps][i_j]*LineNominalVoltage)*(1/p.Sbase)))  
            @constraint(m, [T in 1:p.Ntimesteps], Q[i_j, T] >= -((m[:line_max_amps][i_j]*LineNominalVoltage)*(1/p.Sbase)))
        end
    end
    p.Nequality_cons += length(p.edges) * p.Ntimesteps

    print("\n the p.linelengths is:")
    print(p.linelengths)

end


function dss_parse_transformers(fp::String)
    
    b = Tables.matrix(CSV.File(fp; ignorerepeated=true, header=false, delim=' '))
    b = replace(b, missing => "no_input")   

    BusVoltagesFromTransformers = Dict([])
    Voltage_Regulators = Dict([])

    for z in 1:length(b[:,1])
        print("\n Reading the line number $(z) \n")
        line_temp = b[z,:]
        bus1 = NaN # ensures that the bus1 and bus2 are read before reading other data
        bus2 = NaN
        per_unit_voltage = 0 # reset to zero
        VoltageBus1 = 0
        VoltageBus2 = 0

        # Build the BusVoltagesFromTransformers dictionary
        for i in line_temp
            if startswith(i,"Buses=")
                N = length(i)               
                IndexFirstBus_Start = findfirst("Buses=[", i)[end]
                IndexFirstBus_End = findfirst(",", i)[end] 
                IndexSecondBus_Start = IndexFirstBus_End 
                IndexSecondBus_End = N - 1 
                
                bus1 = strip(chop(i, head=IndexFirstBus_Start, tail= N-IndexFirstBus_End )) 
                bus2 = strip(chop(i, head=IndexSecondBus_Start, tail= N-IndexSecondBus_End))
                
                # eliminate the .1's after the bus names:
                bus1 = chop(bus1, tail=length(bus1)-findfirst(".", bus1)[1]+1)
                bus2 = chop(bus2, tail=length(bus2)-findfirst(".", bus2)[1]+1)

                BusVoltagesFromTransformers = merge!(BusVoltagesFromTransformers, Dict(string(bus1) => Dict("Transformer Side" => "upstream")))
                BusVoltagesFromTransformers = merge!(BusVoltagesFromTransformers, Dict(string(bus2) => Dict("Transformer Side" => "downstream")))
                print(BusVoltagesFromTransformers)
                for i in line_temp
                    if startswith(i, "Transformer.")
                        name = chop(i, head=findfirst("Transformer.", i)[end], tail=0) 
                        merge!(BusVoltagesFromTransformers[string(bus1)], Dict("Transformer Name" => name))
                        merge!(BusVoltagesFromTransformers[string(bus2)], Dict("Transformer Name" => name))
                    else
                    end
                end
            elseif startswith(i,"kVs=")
                N = length(i)
                IndexFirstVoltage_Start = findfirst("kVs=[", i)[end]
                IndexFirstVoltage_End = findfirst(",", i)[end] - 1
                IndexSecondVoltage_Start = IndexFirstVoltage_End + 1
                IndexSecondVoltage_End = N - 1 

                VoltageBus1 = strip(chop(i, head = IndexFirstVoltage_Start, tail=N-IndexFirstVoltage_End) )
                VoltageBus2 = strip(chop(i, head=IndexSecondVoltage_Start, tail=N-IndexSecondVoltage_End))
                
                merge!(BusVoltagesFromTransformers[string(bus1)], Dict("Voltage" => string(VoltageBus1)))
                merge!(BusVoltagesFromTransformers[string(bus2)], Dict("Voltage" => string(VoltageBus2)))
      
            elseif startswith(i, "reg=") 
                value = chop(i, head=findfirst("reg=", i)[end], tail=0)
                if string(value) == "true" # if the reg value was set to true, assign the designated voltage to the downstream side of the transformer
                    for i in line_temp # find the assigned regulator per unit voltage
                        if startswith(i,"reg_per_unit=")
                            per_unit_voltage = chop(i, head=findfirst("reg_per_unit=", i)[end], tail=0)
                            Voltage_Regulators[string(bus2)] = per_unit_voltage
                        end
                        print("\n The reg value for the $(bus1) and $(bus2) transformer was set to a per unit voltage of $(per_unit_voltage)")
                    end
                else
                    print("\n The reg value was set to false for the $(bus1) and $(bus2) transformer")
                end
            elseif startswith(i, "kva=")
                max_kva = chop(i, head=findfirst("kva=", i)[end], tail=0)
                merge!(BusVoltagesFromTransformers[string(bus2)], Dict("MaximumkVa" => max_kva))
            end
        end
    end

    print("\n  The BusVoltageFromTransformers dictionary is: $(BusVoltagesFromTransformers)")
    print("\n  The Voltage_Regulators dictionary is: $(Voltage_Regulators)")
    
    return BusVoltagesFromTransformers, Voltage_Regulators
end   


"""
    function dss_parse_lines(fp::String)

Parse a openDSS line codes file, returning 
    - edges, an array of tuples with 2 values each for the sending and receiving busses on each edge
    - linecodes, an array of string
    - linelengths, an array of float
"""
function dss_parse_lines(fp::String)

    # Read in the .dss files
    a = Tables.matrix(CSV.File(fp; ignorerepeated=true, header=false, delim=' '))
    a = replace(a, missing => "no_input")

    # Parse the data for each line
    edges = Tuple[]
    linecodes = String[]
    linelengths = Float64[]
    linenormamps = Float64[]
    
    LineDataDictionary = Dict([])
    for z in 1:length(a[:,1])
        line_temp = a[z,:]
        LineDataDictionary[string(z)] = Dict([])

        for i in line_temp
            if startswith(i,"Line.")
                value = strip(chop(i, head=findfirst("Line.L", i)[end], tail=0))
                LineDataDictionary[string(z)]["Line"] = value

            elseif startswith(i, "LineCode=") 
                linecode = strip(chop(i, head=findfirst("LineCode=", i)[end], tail=0))
                LineDataDictionary[string(z)]["LineCode"] = linecode
                push!(linecodes, convert(String, linecode))

            elseif startswith(i, "Bus1=")
                value_full_bus_name = string(strip(chop(i, head=findfirst("Bus1=", i)[end], tail=0)))
                value_bus_ID = chop(value_full_bus_name, tail= sizeof(value_full_bus_name)  -findfirst(".", value_full_bus_name)[1]+1) #
                LineDataDictionary[string(z)]["Bus1"] = value_bus_ID
            
            elseif startswith(i, "Bus2=")
                value_full_bus2_name = strip(chop(i, head=findfirst("Bus2=", i)[end], tail=0))
                value_bus2_ID = chop(value_full_bus2_name, tail=sizeof(value_full_bus2_name)-findfirst(".", value_full_bus2_name)[1]+1)
                LineDataDictionary[string(z)]["Bus2"] = value_bus2_ID
            
            elseif startswith(i, "Length=")
                linelength = strip(chop(i, head=findfirst("Length=", i)[end], tail=0))
                LineDataDictionary[string(z)]["Length"] = linelength
                push!(linelengths, parse(Float64, linelength))

            elseif startswith(i, "normamps=")
                normamps = strip(chop(i, head=findfirst("normamps=", i)[end], tail=0))
                LineDataDictionary[string(z)]["normamps"] = normamps
                push!(linenormamps, parse(Float64, normamps))

            elseif startswith(i, "Switch=")
                value = strip(chop(i, head=findfirst("Switch=", i)[end], tail=0))
                LineDataDictionary[string(z)]["Switch"] = value
            end            
        end
        push!(edges, (LineDataDictionary[string(z)]["Bus1"], LineDataDictionary[string(z)]["Bus2"]))   
    end

    print("\n ***** Line codes are: $(linecodes)")
    print("\n ***** Line lengths are: $(linelengths)")
    print("\n ***** Line norm amps are: $(linenormamps)")
    
    return edges, linecodes, linelengths, linenormamps, LineDataDictionary
    
end

#TODO: use the new method in the dss_parse_lines for the line codes files too 
function dss_parse_line_codes(fp::String, linecodes::Array{String, 1})
    d = Dict(c => Dict{String, Any}() for c in linecodes)
    open(fp) do io
        while !eof(io)
            line = readline(io)
            N = length(line)
            if startswith(line, "New linecode")
                code = convert(String, chop(line, head=findfirst(".", line)[end], tail=N-findfirst("nphases", line)[1]+2))
                if code in linecodes
                    while !occursin("rmatrix", line) || startswith(line, "!")
                        line = readline(io)
                    end
                    d[code]["rmatrix"] = dss_parse_string_matrix(line)

                    while !occursin("xmatrix", line) || startswith(line, "!")
                        line = readline(io)
                    end
                    d[code]["xmatrix"] = dss_parse_string_matrix(line)
                    
                    
                end
            end
        end
    end

    return d
end


function dss_parse_string_matrix(line::String)
    N = length(line)
    str_array = split(chop(line, head=findfirst("[", line)[end], tail=N-findfirst("]", line)[1]+1))
    filter!(s -> !occursin("|", s), str_array)
    return parse(Float64, str_array[1])
end


# Utilities

"""
    function i_to_j(j::String, p::Inputs)
        find all busses upstream of bus j
"""
function i_to_j(j::String, p::PowerFlowInputs)
    convert(Array{String, 1}, map(x->x[1], filter(t->t[2]==j, p.edges)))
end


"""
    function j_to_k(j::String, p::Inputs)
        find all busses downstream of bus j
"""
function j_to_k(j::String, p::PowerFlowInputs)
    convert(Array{String, 1}, map(x->x[2], filter(t->t[1]==j, p.edges)))
end


function rij(i::String, j::String, p::PowerFlowInputs)
    linecode = get_ijlinecode(i, j, p)
    linelength = get_ijlinelength(i, j, p)
    linenominalvoltage = p.Zdict[linecode]["nominal_voltage_volts"]   # Retrieve the nominal voltage for each line
    rmatrix = p.Zdict[linecode]["rmatrix"] * linelength * p.Sbase / (linenominalvoltage^2)
    return rmatrix[1]
end


function xij(i::String, j::String, p::PowerFlowInputs)
    linecode = get_ijlinecode(i, j, p)
    linelength = get_ijlinelength(i, j, p)
    linenominalvoltage = p.Zdict[linecode]["nominal_voltage_volts"]      
    xmatrix = p.Zdict[linecode]["xmatrix"] * linelength * p.Sbase / (linenominalvoltage^2)
    return xmatrix[1]
end


function get_ijlinelength(i::String, j::String, p::PowerFlowInputs)
    ij_idxs = get_ij_idxs(i, j, p)
    return p.linelengths[ij_idxs[1]]
end


function get_ijlinecode(i::String, j::String, p::PowerFlowInputs)
    ij_idxs = get_ij_idxs(i, j, p)
    return p.linecodes[ij_idxs[1]]
end

function get_ijlinenormamps(i::String, j::String, p::PowerFlowInputs)
    ij_idxs = get_ij_idxs(i, j, p)
    return p.linenormamps[ij_idxs[1]]
end

function get_ijedge(i::String, j::String, p::PowerFlowInputs)
    ij_idxs = get_ij_idxs(i, j, p)
    return p.edges[ij_idxs[1]]
end


function get_ij_idxs(i::String, j::String, p::PowerFlowInputs)
    ij_idxs = findall(t->(t[1]==i && t[2]==j), p.edges)
    if length(ij_idxs) > 1
        error("found more than one edge for i=$i and j=$j")
    elseif length(ij_idxs) == 0
        error("found no matching edges for i=$i and j=$j")
    else
        return ij_idxs
    end
end
