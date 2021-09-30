#=
Given the optimal battery dispatch from REopt (with a PV system in the results)
fit a Decision Tree to the output the change in the batter state-of-charge given:
- Current state-of-charge (kWh)
- Current demand (kW)
- Previous demand (kW)
- Current PV production (kW)
- Current time step in the day (integer)
- Current month of the year (integer)
which provides a heuristic control method for a battery system.
=#


function fit(p::REoptInputs, d::Dict)

    # return a fitted Decision Tree model using fit! method from DecisionTree.jl
    # then can use DecisionTree.predict to get next SOC (might need to create a custom dispatch)
end