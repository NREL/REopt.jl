

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
regulators::Dict
transformers::Dict
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
regulators=Dict(),
transformers=Dict()
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
    regulators,
    transformers
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
Q_lo_bound=-1e4,
regulators=Dict(),
)
edges, linecodes, linelengths, linenormamps = dss_parse_lines(dsslinesfilepath)
linecodes_dict = dss_parse_line_codes(dsslinecodesfilepath, linecodes)


if dsstransformersfilepath == "None"
    @info "No transformers were input into the model"
    transformers_dict = Dict(["NoTransformer","NoTransformer"])
else
    @info "Transformers have been input into the model"
    transformers_dict = dss_parse_transformers(dsstransformersfilepath)
    print("\n Transformers included are: $(transformers_dict)")
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
    regulators = regulators,
    transformers= transformers_dict
)
end



function build_power_flow!(m::JuMP.AbstractModel, p::PowerFlowInputs)

    add_variables(m, p)
    constrain_power_balance(m, p)  # (10a)
    constrain_substation_voltage(m, p)  # (10c)
    constrain_KVL(m, p)  # (10e)
    constrain_loads(m, p)
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

function DetermineLineNominalVoltage(p::PowerFlowInputs)  # new function added by TEO to determine the nominal line voltage
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
                BusVoltage = string(p.Vbase) # this is already in volts
                print("\n  Bus "*string(node)*" is the substation, with a nominal voltage of "*string(BusVoltage))
                # there are no lines upstream of the substation in the network, so don't define a line voltage here
            else 
                UpstreamNode_vector = i_to_j(node, p) 
                UpstreamNode = UpstreamNode_vector[1]
                KeepSearchingNetwork = true
                for x in 1:length(p.busses)+1 
                    if UpstreamNode == p.substation_bus
                        # Bus nominal voltages
                        BusVoltage = string(p.Vbase) # Vbase is already in units of volts
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

function constrain_KVL(m, p::PowerFlowInputs) 
    
    w = m[:vsqrd]
    P = m[:Pᵢⱼ] 
    Q = m[:Qᵢⱼ]

    LineNominalVoltages_dict, BusNominalVoltages_dict = DetermineLineNominalVoltage(p)

    for j in p.busses
        for i in i_to_j(j, p)
            i_j = string(i*"-"*j)
            i_j_underscore = string(i*"_"*j)
            linelength = get_ijlinelength(i, j, p)
            linenormamps = get_ijlinenormamps(i,j,p)
            line_code = get_ijlinecode(i,j,p) 
            LineNominalVoltage = parse(Float64,LineNominalVoltages_dict[i_j])
            
            rmatrix = p.Zdict[line_code]["rmatrix"]

            print("\n For line $(i_j) and linecode $(line_code): the rmatrix is $(rmatrix), the max amperage is $(linenormamps)A and the nominal voltage is $(LineNominalVoltage)V, so the maximum power is: "*string(LineNominalVoltage*linenormamps)*" W")
                       
            rᵢⱼ = p.Zdict[line_code]["rmatrix"] * linelength * p.Sbase / (LineNominalVoltage^2)
            
            xᵢⱼ = p.Zdict[line_code]["xmatrix"] * linelength * p.Sbase / (LineNominalVoltage^2)
            
            # TODO: delete this section because will handle voltage regulators as a transformer; Apply voltage change from the voltage regulator
            if (j in keys(p.regulators))
                @constraint(m, [t in 1:p.Ntimesteps], w[j,t] == p.regulators[j])
                print("\n  Applying voltage regulator to node: "*j)
            else 
                vcon = @constraint(m, [t in 1:p.Ntimesteps],
                    w[j,t] == w[i,t]
                        - 2*(rᵢⱼ * P[i_j,t] +  xᵢⱼ * Q[i_j,t])    
                )
            
            end

            # Apply the amperage constraints to the line:
            @constraint(m, [T in 1:p.Ntimesteps], P[i_j, T] <= ((linenormamps*LineNominalVoltage)*(1/p.Sbase))) # Note: 1 instead of 1000 because not converting from kW 
            @constraint(m, [T in 1:p.Ntimesteps], P[i_j, T] >= -((linenormamps*LineNominalVoltage)*(1/p.Sbase)))
            
            @constraint(m, [T in 1:p.Ntimesteps], Q[i_j, T] <= ((linenormamps*LineNominalVoltage)*(1/p.Sbase)))  
            @constraint(m, [T in 1:p.Ntimesteps], Q[i_j, T] >= -((linenormamps*LineNominalVoltage)*(1/p.Sbase)))
        end
    end
    p.Nequality_cons += length(p.edges) * p.Ntimesteps

    print("\n the line_norm_amps is:")
    print(p.linenormamps)
    print("\n the p.linelengths is:")
    print(p.linelengths)

end


"""
    constrain_loads(m, p::Inputs)

- set loads to negative of Inputs.Pload, which are normalized by Sbase when creating Inputs
- keys of Pload must match Inputs.busses. Any missing keys have load set to zero.
- Inputs.substation_bus is unconstrained, slack bus
"""
function constrain_loads(m, p::PowerFlowInputs)
    Pⱼ = m[:Pⱼ]
    Qⱼ = m[:Qⱼ]
    
    for j in p.busses
        if j in keys(p.Pload)
            @constraint(m, [t in 1:p.Ntimesteps],
                Pⱼ[j,t] == -p.Pload[j][t]
            )
        elseif j != p.substation_bus
            @constraint(m, [t in 1:p.Ntimesteps],
                Pⱼ[j,t] == 0
            )
        end
        if j in keys(p.Qload)
            @constraint(m, [t in 1:p.Ntimesteps],
                Qⱼ[j,t] == -p.Qload[j][t]
            )
        elseif j != p.substation_bus
            @constraint(m, [t in 1:p.Ntimesteps],
                Qⱼ[j,t] == 0
            )
        end
    end
    
    p.Nequality_cons += 2 * (p.Nnodes - 1) * p.Ntimesteps
end


function constrain_bounds(m::JuMP.AbstractModel, p::PowerFlowInputs)
    @info("constrain_bounds is deprecated. Include bounds in inputs.")
    nothing
end


function dss_parse_transformers(fp::String)
    
    BusVoltagesFromTransformers = Dict([]) 
   
    for line in eachline(fp)
        N = length(line)
        if startswith(line, "New Transformer")
            name = chop(line, head=findfirst(".", line)[end], tail=N-findnext(" ", line, findfirst(".", line)[end])[1]+1)
            print("\n  Updates added")
            if startswith(name, "T") # T identifies the start of the transformer name 
                # use the findfirst and findnext functions to pull out the bus names and bus voltages from the transformer file
                IndexFirstBus_Start = findfirst("Buses=[", line)[end]
                IndexFirstBus_End = N - findnext(" ", line, findfirst("Buses=[", line)[end])[1]+1
                IndexSecondBus_Start = findnext(" ", line, findfirst("Buses=[", line)[end])[1] 
                IndexSecondBus_End = N - findnext("]", line, IndexSecondBus_Start)[1]+1

                bus1 = strip(chop(line, head=IndexFirstBus_Start, tail= IndexFirstBus_End )) 
                bus2 = strip(chop(line, head=IndexSecondBus_Start, tail= IndexSecondBus_End))

                # eliminate the .1's after the bus names:
                bus1 = chop(bus1, tail=length(bus1)-findfirst(".", bus1)[1]+1)
                bus2 = chop(bus2, tail=length(bus2)-findfirst(".", bus2)[1]+1)
                print("\n bus1 is $(bus1) and bus2 is $(bus2)")
                
                IndexFirstVoltage_Start = findfirst("kVs=[", line)[end]
                IndexFirstVoltage_End = N-findnext(" ", line, findfirst("kVs=[", line)[end])[1]+1
                IndexSecondVoltage_Start = findnext(" ", line, findfirst("kVs=[", line)[end])[1]
                IndexSecondVoltage_End = N - findnext("]", line, IndexSecondVoltage_Start)[1]+1

                VoltageBus1 = strip(chop(line, head = IndexFirstVoltage_Start, tail=IndexFirstVoltage_End) )
                VoltageBus2 = strip(chop(line, head=IndexSecondVoltage_Start, tail=IndexSecondVoltage_End))
     
                BusVoltagesFromTransformers = merge!(BusVoltagesFromTransformers, Dict(string(bus1) => Dict("Voltage" => string(VoltageBus1), "Transformer Name" => name, "Transformer Side" => "upstream")))
                BusVoltagesFromTransformers = merge!(BusVoltagesFromTransformers, Dict(string(bus2) => Dict("Voltage" => string(VoltageBus2), "Transformer Name" => name, "Transformer Side" => "downstream")))
                 
            end 
        end
    end

    print("\n  BusVoltageFromTransformers variable: $(BusVoltagesFromTransformers)")

    return BusVoltagesFromTransformers   

    #=
    #TODO: use the new method in the dss_parse_lines for the transformer files too 
    b = Tables.matrix(CSV.File(fp; ignorerepeated=true, header=false, delim=' '))
    b = replace(b, missing => "no_input")

    BusVoltagesFromTransformers = Dict([])

    for z in 1:length(b[:,1])
        line_temp = b[z,:]      

    return BusVoltagesFromTransformers   
    =#
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


function get_edge_values(var_prefix::String, m::JuMP.AbstractModel, p::PowerFlowInputs)
    vals = Float64[]
    for edge in p.edges
        var = string(var_prefix, "[", edge[1], "-", edge[2], "]")
        try
            val = value(variable_by_name(m, var))
            if startswith(var_prefix, "l")
                val = sqrt(val)
            end
            push!(vals, round(val; digits=8))
        catch e
            println(var, "failed", e)
        end
    end
    return vals
end


function get_bus_values(var_prefix::String, m::JuMP.AbstractModel, p::PowerFlowInputs)
    vals = Float64[]
    for b in p.busses
        var = string(var_prefix,  "[", b, "]")
        try
            val = value(variable_by_name(m, var))
            if startswith(var_prefix, "v")
                val = sqrt(val)
            end
            push!(vals, round(val; digits=7))
        catch e
            println(var, " failed: ", e)
        end
    end
    return vals
end


function get_constraints_by_variable_name(m, v::String)
    ac = ConstraintRef[]
    for tup in list_of_constraint_types(m)
        append!(ac, all_constraints(m, tup[1], tup[2]))
    end
    filter( cr -> occursin(v, string(cr)), ac )
end

#=
"""
    function recover_voltage_current(m, p::Inputs)

Algorithm 2 from Gan & Low 2014
"""
function recover_voltage_current(m, p::Inputs, nodetobusphase)
    # TODO finish converting this to single phase, validate
    Iij = Dict{String, Array{Complex, 1}}()
    Vj = Dict{String, Array{Complex, 1}}()
    Vj[p.substation_bus] = [p.v0*exp(0im)]

    for i in p.busses
        for j in j_to_k(i,p)
            tr_vᵢ = zeros(3)
            Pᵢⱼ = zeros(3,3)
            Qᵢⱼ = zeros(3,3)

            tr_vᵢ = value(variable_by_name(m, string("vⱼ", "[", i, "]")))
            Pᵢⱼ = value(variable_by_name(m, string("Pᵢⱼ", "[", i, "-", j, "]")))
            Qᵢⱼ = value(variable_by_name(m, string("Qᵢⱼ", "[", i, "-", j, "]")))
            
            Sᵢⱼ = @. complex(Pᵢⱼ, Qᵢⱼ)
            r = rij(i,j,p)
            x = xij(i,j,p)
            zᵢⱼ = @. complex(r, x)

            Iij[i*"-"*j] = 1/sum(tr_vᵢ) * Sᵢⱼ' * Vj[i]
            Vj[j] = Vj[i] - zᵢⱼ * Iij[i*"-"*j]
        end
    end
    # convert dicts to vectors in same order as nodetobusphase
    v = Complex[]
    c = Complex[]

    for busphase in [split(bp, ".") for bp in nodetobusphase]
        b = busphase[1]
        ph = parse(Int, busphase[2])
        push!(v, Vj[b][ph])
    end
    return v, Iij
end
=#




