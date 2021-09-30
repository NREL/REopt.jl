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


function make_decision_tree_model(p::REoptInputs, d::Dict)

    # create the feature vectors
    pv_prod = d["PV"]["year_one_to_load_series_kw"] +
              d["PV"]["year_one_to_grid_series_kw"] +
              d["PV"]["year_one_to_battery_series_kw"] +
              d["PV"]["year_one_curtailed_production_series_kw"];
    soc_vec = append!([p.s.storage.soc_init_pct[:elec]], d["Storage"]["year_one_soc_series_pct"]);
    soc_diff = diff(soc_vec);
    prev_soc = soc_vec[1:end-1];
    demand = d["ElectricLoad"]["load_series_kw"];
    demand_diff = append!([0.0], diff(demand));
    hours = repeat(collect(1:24), 365);
    months = Int64[]
    for mth in 1:12
        push!(months, repeat([mth], 24*daysinmonth(Date(p.s.electric_load.year, mth)))...)
    end

    features = Matrix{Float64}(undef, 8760, 6);
    features[:, 1] .= demand;
    features[:, 2] .= demand_diff;
    features[:, 3] .= pv_prod;
    features[:, 4] .= prev_soc;
    features[:, 5] .= hours;
    features[:, 6] .= months;
    @info """use DecisionTree.predict(classifier, [demand_kw, delta_demand_kw, pv_kw, SOC, hour, month]) 
        to get the change in SOC."""

    labels = soc_diff;

    classifier = DecisionTreeClassifier()
    fit!(classifier, features, labels)
    return classifier
end