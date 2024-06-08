# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
    Metrics

Convenience mutable struct for passing data between proforma methods
"""
mutable struct Metrics
    federal_itc::Float64
    om_series::Array{Float64, 1}
    om_series_bau::Array{Float64, 1}
    total_pbi::Array{Float64, 1}
    total_pbi_bau::Array{Float64, 1}
    total_depreciation::Array{Float64, 1}
    total_ibi_and_cbi::Float64
end


"""
    calculate_proforma_metrics(p::REoptInputs, d::Dict)

Recreates the ProForma spreadsheet calculations to get the simple payback period, irr, net present cost (3rd
party case), and payment to third party (3rd party case).

return Dict(
    "simple_payback_years" => 0.0,
    "internal_rate_of_return" => 0.0,
    "net_present_cost" => 0.0,
    "annualized_payment_to_third_party" => 0.0,
    "offtaker_annual_free_cashflows" => Float64[],
    "offtaker_annual_free_cashflows_bau" => Float64[],
    "offtaker_discounted_annual_free_cashflows" => Float64[],
    "offtaker_discounted_annual_free_cashflows_bau" => Float64[],
    "developer_annual_free_cashflows" => Float64[]
)
"""
function proforma_results(p::REoptInputs, d::Dict)
    r = Dict(
        "simple_payback_years" => 0.0,
        "internal_rate_of_return" => 0.0,
        "net_present_cost" => 0.0,
        "annualized_payment_to_third_party" => 0.0,
        "offtaker_annual_free_cashflows" => Float64[],
        "offtaker_annual_free_cashflows_bau" => Float64[],
        "offtaker_discounted_annual_free_cashflows" => Float64[],
        "offtaker_discounted_annual_free_cashflows_bau" => Float64[],
        "developer_annual_free_cashflows" => Float64[]
    )
    years = p.s.financial.analysis_years
    escalate_elec(val) = [-1 * val * (1 + p.s.financial.elec_cost_escalation_rate_fraction)^yr for yr in 1:years]
    escalate_om(val) = [val * (1 + p.s.financial.om_cost_escalation_rate_fraction)^yr for yr in 1:years]
    third_party = p.s.financial.third_party_ownership
    
    # Create placeholder variables to store summed totals across all relevant techs
    m = Metrics(0, zeros(years), zeros(years), zeros(years), zeros(years), zeros(years), 0)

    # calculate PV o+m costs, incentives, and depreciation
    for pv in p.s.pvs
        update_metrics(m, p, pv, pv.name, d, third_party)
    end

    # calculate Wind o+m costs, incentives, and depreciation
    if "Wind" in keys(d) && d["Wind"]["size_kw"] > 0
        update_metrics(m, p, p.s.wind, "Wind", d, third_party)
    end

    # calculate Storage o+m costs, incentives, and depreciation
    if "ElectricStorage" in keys(d) && d["ElectricStorage"]["size_kw"] > 0
        # TODO handle other types of storage
        storage = p.s.storage.attr["ElectricStorage"]
        total_kw = d["ElectricStorage"]["size_kw"]
        total_kwh = d["ElectricStorage"]["size_kwh"]
        capital_cost = total_kw * storage.installed_cost_per_kw + total_kwh * storage.installed_cost_per_kwh
        battery_replacement_year = storage.battery_replacement_year
        battery_replacement_cost = -1 * ((total_kw * storage.replace_cost_per_kw) + (
                    total_kwh * storage.replace_cost_per_kwh))
        m.om_series += [yr != battery_replacement_year ? 0 : battery_replacement_cost for yr in 1:years]

        # storage only has cbi in the API
        cbi = total_kw * storage.total_rebate_per_kw + total_kwh * storage.total_rebate_per_kwh
        m.total_ibi_and_cbi += cbi

        # ITC
        federal_itc_basis = capital_cost  # bug in v1 subtracted cbi from capital_cost here
        federal_itc_amount = storage.total_itc_fraction * federal_itc_basis
        m.federal_itc += federal_itc_amount

        # Depreciation
        if storage.macrs_option_years in [5, 7]
            schedule = []
            if storage.macrs_option_years == 5
                schedule = p.s.financial.macrs_five_year
            elseif storage.macrs_option_years == 7
                schedule = p.s.financial.macrs_seven_year
            end
            macrs_bonus_basis = federal_itc_basis * (1 - storage.total_itc_fraction * storage.macrs_itc_reduction)
            macrs_basis = macrs_bonus_basis * (1 - storage.macrs_bonus_fraction)

            depreciation_schedule = zeros(years)
            for (i, r) in enumerate(schedule)
                if i < length(depreciation_schedule)
                    depreciation_schedule[i] = macrs_basis * r
                end
            end
            depreciation_schedule[1] += storage.macrs_bonus_fraction * macrs_bonus_basis
            m.total_depreciation += depreciation_schedule
        end
    end

    # calculate Generator o+m costs, incentives, and depreciation
    if "Generator" in keys(d) && d["Generator"]["size_kw"] > 0
        # In the two party case the developer does not include the fuel cost in their costs
        # It is assumed that the offtaker will pay for this at a rate that is not marked up
        # to cover developer profits
        fixed_and_var_om = d["Generator"]["year_one_fixed_om_cost_before_tax"] + d["Generator"]["year_one_variable_om_cost_before_tax"]
        fixed_and_var_om_bau = 0.0
        year_one_fuel_cost_bau = 0.0
        if p.s.generator.existing_kw > 0
            fixed_and_var_om_bau = d["Generator"]["year_one_fixed_om_cost_before_tax_bau"] + 
                                   d["Generator"]["year_one_variable_om_cost_before_tax_bau"]
            year_one_fuel_cost_bau = d["Generator"]["year_one_fuel_cost_before_tax_bau"]
        end
        if !third_party
            annual_om = -1 * (fixed_and_var_om + d["Generator"]["year_one_fuel_cost_before_tax"])

            annual_om_bau = -1 * (fixed_and_var_om_bau + year_one_fuel_cost_bau)
        else
            annual_om = -1 * fixed_and_var_om

            annual_om_bau = -1 * fixed_and_var_om_bau
        end

        m.om_series += escalate_om(annual_om)
        m.om_series_bau += escalate_om(annual_om_bau)
    end

    # calculate GHP incentives, and depreciation
    if "GHP" in keys(d) && d["GHP"]["ghp_option_chosen"] > 0
        update_ghp_metrics(m, p, p.s.ghp_option_list[d["GHP"]["ghp_option_chosen"]], "GHP", d, third_party)
    end

    # Optimal Case calculations
    electricity_bill_series = escalate_elec(d["ElectricTariff"]["year_one_bill_before_tax"])
    export_credit_series = escalate_elec(-d["ElectricTariff"]["year_one_export_benefit_before_tax"])

    # In the two party case the electricity and export credits are incurred by the offtaker not the developer
    if third_party
        total_operating_expenses = m.om_series
        tax_rate_fraction = p.s.financial.owner_tax_rate_fraction
    else
        total_operating_expenses = electricity_bill_series + export_credit_series + m.om_series
        tax_rate_fraction = p.s.financial.offtaker_tax_rate_fraction
    end

    # Apply taxes to operating expenses
    if tax_rate_fraction > 0
        deductable_operating_expenses_series = copy(total_operating_expenses)
    else
        deductable_operating_expenses_series = zeros(years)
    end

    operating_expenses_after_tax = (total_operating_expenses - deductable_operating_expenses_series) + 
                                    deductable_operating_expenses_series * (1 - tax_rate_fraction)
    total_cash_incentives = m.total_pbi * (1 - tax_rate_fraction)
    free_cashflow_without_year_zero = m.total_depreciation * tax_rate_fraction + total_cash_incentives + operating_expenses_after_tax
    free_cashflow_without_year_zero[1] += m.federal_itc
    free_cashflow = append!([(-1 * d["Financial"]["initial_capital_costs"]) + m.total_ibi_and_cbi], free_cashflow_without_year_zero)

    # At this point the logic branches based on third-party ownership or not - see comments    
    if third_party  # get cumulative cashflow for developer
        r["developer_annual_free_cashflows"] = copy(free_cashflow)
        discounted_developer_cashflow = [v / ((1 + p.s.financial.owner_discount_rate_fraction)^(yr-1)) for (yr, v) in
                                         enumerate(r["developer_annual_free_cashflows"])]
        r["net_present_cost"] = sum(discounted_developer_cashflow) * -1

        if p.s.financial.owner_discount_rate_fraction != 0
            capital_recovery_factor = (p.s.financial.owner_discount_rate_fraction * (1 + p.s.financial.owner_discount_rate_fraction)^years) / 
                                      ((1 + p.s.financial.owner_discount_rate_fraction)^years - 1) / (1 - tax_rate_fraction)
        else
            capital_recovery_factor = (1 / years) / (1 - tax_rate_fraction)
        end

        r["annualized_payment_to_third_party"] = r["net_present_cost"] * capital_recovery_factor
        annual_income_from_host = -1 * sum(discounted_developer_cashflow) * capital_recovery_factor * (1 - tax_rate_fraction)
        r["developer_annual_free_cashflows"][2:end] .+= annual_income_from_host
        r["internal_rate_of_return"] = irr(r["developer_annual_free_cashflows"])
        cumulative_cashflow = cumsum(r["developer_annual_free_cashflows"])
        net_free_cashflow = r["developer_annual_free_cashflows"]
        r["developer_annual_free_cashflows"] = round.(r["developer_annual_free_cashflows"], digits=2)

        electricity_bill_series = escalate_elec(d["ElectricTariff"]["year_one_bill_before_tax"])
        electricity_bill_series_bau = escalate_elec(d["ElectricTariff"]["year_one_bill_before_tax_bau"])

        export_credit_series = escalate_elec(-d["ElectricTariff"]["year_one_export_benefit_before_tax"])
        export_credit_series_bau = escalate_elec(-d["ElectricTariff"]["year_one_export_benefit_before_tax_bau"])

        annual_income_from_host_series = repeat([-1 * r["annualized_payment_to_third_party"]], years)

        if "Generator" in keys(d) && d["Generator"]["size_kw"] > 0
            generator_fuel_cost_series = escalate_om(-1 * d["Generator"]["year_one_fuel_cost_before_tax"])
            if p.s.generator.existing_kw > 0
                existing_genertor_fuel_cost_series = escalate_om(-1 * d["Generator"]["year_one_fuel_cost_before_tax_bau"])
            else
                existing_genertor_fuel_cost_series = zeros(years)
            end
        else
            existing_genertor_fuel_cost_series = zeros(years)
            generator_fuel_cost_series = zeros(years)
        end
        net_energy_costs = -electricity_bill_series_bau - export_credit_series_bau + electricity_bill_series + 
                           export_credit_series + annual_income_from_host_series - existing_genertor_fuel_cost_series + 
                           generator_fuel_cost_series

        if p.s.financial.owner_tax_rate_fraction > 0
            deductable_net_energy_costs = copy(net_energy_costs)
        else
            deductable_net_energy_costs = zeros(years)
        end

        r["offtaker_annual_free_cashflows"] = append!([0.0], 
            electricity_bill_series + export_credit_series + generator_fuel_cost_series + annual_income_from_host_series
        )
        r["offtaker_annual_free_cashflows_bau"] = append!([0.0], 
            electricity_bill_series_bau + export_credit_series_bau + existing_genertor_fuel_cost_series
            )

    else  # get cumulative cashflow for offtaker
        electricity_bill_series_bau = escalate_elec(d["ElectricTariff"]["year_one_bill_before_tax_bau"])
        export_credit_series_bau = escalate_elec(-d["ElectricTariff"]["year_one_export_benefit_before_tax_bau"])
        total_operating_expenses_bau = electricity_bill_series_bau + export_credit_series_bau + m.om_series_bau
        total_cash_incentives_bau = m.total_pbi_bau * (1 - p.s.financial.offtaker_tax_rate_fraction)

        if p.s.financial.offtaker_tax_rate_fraction > 0
            deductable_operating_expenses_series_bau = copy(total_operating_expenses_bau)
        else
            deductable_operating_expenses_series_bau = zeros(years)
        end

        operating_expenses_after_tax_bau = total_operating_expenses_bau - deductable_operating_expenses_series_bau + 
                    deductable_operating_expenses_series_bau * (1 - p.s.financial.offtaker_tax_rate_fraction)
        free_cashflow_bau = operating_expenses_after_tax_bau + total_cash_incentives_bau
        free_cashflow_bau = append!([0.0], free_cashflow_bau)
        r["offtaker_annual_free_cashflows"] = round.(free_cashflow, digits=2)
        r["offtaker_discounted_annual_free_cashflows"] = [round(
            v / ((1 + p.s.financial.offtaker_discount_rate_fraction)^(yr-1)), 
            digits=2) for (yr, v) in enumerate(r["offtaker_annual_free_cashflows"])]
        r["offtaker_annual_free_cashflows_bau"] = round.(free_cashflow_bau, digits=2)
        r["offtaker_discounted_annual_free_cashflows_bau"] = [round(
            v / ((1 + p.s.financial.offtaker_discount_rate_fraction)^(yr-1)), 
            digits=2) for (yr, v) in enumerate(free_cashflow_bau)]
        # difference optimal and BAU
        net_free_cashflow = free_cashflow - free_cashflow_bau
        r["internal_rate_of_return"] = irr(net_free_cashflow)
        cumulative_cashflow = cumsum(net_free_cashflow)
    end

    # At this point we have the cumulative_cashflow for the developer or offtaker so the payback calculation is the same
    if cumulative_cashflow[end] < 0  
        # case where the system does not pay itself back in the analysis period, do not caculate SPP and IRR
        return r
    end

    for i in 2:years
        # add years where the cumulative cashflow is negative
        if cumulative_cashflow[i] < 0
            r["simple_payback_years"] += 1
        # fractionally add years where the cumulative cashflow became positive
        elseif cumulative_cashflow[i - 1] < 0 && cumulative_cashflow[i] > 0
            r["simple_payback_years"] += -(cumulative_cashflow[i - 1] / net_free_cashflow[i])
        # skip years where cumulative cashflow is positive and the previous year's is too
        end
    end
    r["simple_payback_years"] = round(r["simple_payback_years"], digits=2)

    return r
end


"""
    update_metrics(m::Metrics, p::REoptInputs, tech::AbstractTech, tech_name::String, results::Dict, third_party::Bool)

Update the Metrics struct for the given `tech`
"""
function update_metrics(m::Metrics, p::REoptInputs, tech::AbstractTech, tech_name::String, results::Dict, third_party::Bool)
    total_kw = results[tech_name]["size_kw"]
    existing_kw = :existing_kw in fieldnames(typeof(tech)) ? tech.existing_kw : 0
    new_kw = total_kw - existing_kw
    capital_cost = new_kw * tech.installed_cost_per_kw

    # owner is responsible for both new and existing PV maintenance in optimal case
    if third_party
        annual_om = -1 * new_kw * tech.om_cost_per_kw
    else
        annual_om = -1 * total_kw * tech.om_cost_per_kw
    end
    years = p.s.financial.analysis_years
    escalate_om(val) = [val * (1 + p.s.financial.om_cost_escalation_rate_fraction)^yr for yr in 1:years]
    m.om_series += escalate_om(annual_om)
    m.om_series_bau += escalate_om(-1 * existing_kw * tech.om_cost_per_kw)

    # incentive calculations, in the spreadsheet utility incentives are applied first
    utility_ibi = minimum([capital_cost * tech.utility_ibi_fraction, tech.utility_ibi_max])
    utility_cbi = minimum([new_kw * tech.utility_rebate_per_kw, tech.utility_rebate_max])
    state_ibi = minimum([(capital_cost - utility_ibi - utility_cbi) * tech.state_ibi_fraction, tech.state_ibi_max])
    state_cbi = minimum([new_kw * tech.state_rebate_per_kw, tech.state_rebate_max])
    federal_cbi = new_kw * tech.federal_rebate_per_kw
    ibi = utility_ibi + state_ibi
    cbi = utility_cbi + federal_cbi + state_cbi
    m.total_ibi_and_cbi += ibi + cbi

    # Production-based incentives
    pbi_series = Float64[]
    pbi_series_bau = Float64[]
    existing_energy_bau = third_party ? get(results[tech_name], "year_one_energy_produced_kwh_bau", 0) : 0
    year_one_energy = "year_one_energy_produced_kwh" in keys(results[tech_name]) ? results[tech_name]["year_one_energy_produced_kwh"] : results[tech_name]["annual_energy_produced_kwh"]
    for yr in range(0, stop=years-1)
        if yr < tech.production_incentive_years
            degradation_fraction = :degradation_fraction in fieldnames(typeof(tech)) ? (1 - tech.degradation_fraction)^yr : 1.0
            base_pbi = minimum([
                tech.production_incentive_per_kwh * (year_one_energy - existing_energy_bau) * degradation_fraction,  
                tech.production_incentive_max_benefit * degradation_fraction
            ])
            base_pbi_bau = minimum([
                tech.production_incentive_per_kwh * get(results[tech_name], "year_one_energy_produced_kwh_bau", 0) * degradation_fraction,  
                tech.production_incentive_max_benefit * degradation_fraction 
            ])
            push!(pbi_series, base_pbi)
            push!(pbi_series_bau, base_pbi_bau)
        else
            push!(pbi_series, 0.0)
            push!(pbi_series_bau, 0.0)
        end
    end
    m.total_pbi += pbi_series
    m.total_pbi_bau += pbi_series_bau

    # Federal ITC 
    # NOTE: bug in v1 has the ITC within the `if tech.macrs_option_years in [5 ,7]` block.
    # NOTE: bug in v1 reduces the federal_itc_basis with the federal_cbi, which is incorrect
    federal_itc_basis = capital_cost - state_ibi - utility_ibi - state_cbi - utility_cbi
    federal_itc_amount = tech.federal_itc_fraction * federal_itc_basis
    m.federal_itc += federal_itc_amount

    # Depreciation
    if tech.macrs_option_years in [5 ,7]
        schedule = []
        if tech.macrs_option_years == 5
            schedule = p.s.financial.macrs_five_year
        elseif tech.macrs_option_years == 7
            schedule = p.s.financial.macrs_seven_year
        end

        macrs_bonus_basis = federal_itc_basis - federal_itc_basis * tech.federal_itc_fraction * tech.macrs_itc_reduction
        macrs_basis = macrs_bonus_basis * (1 - tech.macrs_bonus_fraction)

        depreciation_schedule = zeros(years)
        for (i, r) in enumerate(schedule)
            if i < length(depreciation_schedule)
                depreciation_schedule[i] = macrs_basis * r
            end
        end
        depreciation_schedule[1] += (tech.macrs_bonus_fraction * macrs_bonus_basis)
        m.total_depreciation += depreciation_schedule
    end
    nothing
end

function update_ghp_metrics(m::REopt.Metrics, p::REoptInputs, tech::REopt.AbstractTech, tech_name::String, results::Dict, third_party::Bool)
    if tech.heat_pump_configuration == "WWHP"
        total_heating_kw = results[tech_name]["size_wwhp_heating_pump_ton"]
        total_cooling_kw = results[tech_name]["size_wwhp_cooling_pump_ton"]
        new_kw = (total_heating_kw + total_cooling_kw) / 2.0  # WIP workaround, not ideal
        capital_cost = total_heating_kw * tech.wwhp_heating_pump_installed_cost_curve[2] + 
                        total_cooling_kw * tech.wwhp_cooling_pump_installed_cost_curve[2]
    else
        new_kw = results[tech_name]["size_heat_pump_ton"]
        capital_cost = new_kw * tech.installed_cost_per_kw[2]
    end

    # building specific OM costs
    annual_om = -1 * tech.building_sqft*tech.om_cost_per_sqft_year
    
    years = p.s.financial.analysis_years
    escalate_om(val) = [val * (1 + p.s.financial.om_cost_escalation_rate_fraction)^yr for yr in 1:years]
    m.om_series += escalate_om(annual_om)
    m.om_series_bau += escalate_om(0)

    # incentive calculations, in the spreadsheet utility incentives are applied first
    utility_ibi = minimum([capital_cost * tech.utility_ibi_fraction, tech.utility_ibi_max])
    utility_cbi = minimum([new_kw * tech.utility_rebate_per_kw, tech.utility_rebate_max])
    state_ibi = minimum([(capital_cost - utility_ibi - utility_cbi) * tech.state_ibi_fraction, tech.state_ibi_max])
    state_cbi = minimum([new_kw * tech.state_rebate_per_kw, tech.state_rebate_max])
    federal_cbi = new_kw * tech.federal_rebate_per_kw
    ibi = utility_ibi + state_ibi
    cbi = utility_cbi + federal_cbi + state_cbi
    m.total_ibi_and_cbi += ibi + cbi

    # Production-based incentives
    pbi_series = Float64[]
    pbi_series_bau = Float64[]
    # existing_energy_bau = third_party ? get(results[tech_name], "year_one_energy_produced_kwh_bau", 0) : 0
    # year_one_energy = "year_one_energy_produced_kwh" in keys(results[tech_name]) ? results[tech_name]["year_one_energy_produced_kwh"] : results[tech_name]["annual_energy_produced_kwh"]
    for yr in range(0, stop=years-1)
        push!(pbi_series, 0.0)
        push!(pbi_series_bau, 0.0)
    end
    m.total_pbi += pbi_series
    m.total_pbi_bau += pbi_series_bau

    # Federal ITC 
    # NOTE: bug in v1 has the ITC within the `if tech.macrs_option_years in [5 ,7]` block.
    # NOTE: bug in v1 reduces the federal_itc_basis with the federal_cbi, which is incorrect
    federal_itc_basis = capital_cost - state_ibi - utility_ibi - state_cbi - utility_cbi
    federal_itc_amount = tech.federal_itc_fraction * federal_itc_basis
    m.federal_itc += federal_itc_amount

    # Depreciation
    if tech.macrs_option_years in [5 ,7]
        schedule = []
        if tech.macrs_option_years == 5
            schedule = p.s.financial.macrs_five_year
        elseif tech.macrs_option_years == 7
            schedule = p.s.financial.macrs_seven_year
        end

        macrs_bonus_basis = federal_itc_basis - federal_itc_basis * tech.federal_itc_fraction * tech.macrs_itc_reduction
        macrs_basis = macrs_bonus_basis * (1 - tech.macrs_bonus_fraction)

        depreciation_schedule = zeros(years)
        for (i, r) in enumerate(schedule)
            if i < length(depreciation_schedule)
                depreciation_schedule[i] = macrs_basis * r
            end
        end
        depreciation_schedule[1] += (tech.macrs_bonus_fraction * macrs_bonus_basis)
        m.total_depreciation += depreciation_schedule
    end
    nothing
end

function npv(cashflows::AbstractArray{<:Real, 1}, rate::Real)
    years = collect(0:length(cashflows)-1)
    return sum( cashflows ./ (1+rate).^years)
end


function irr(cashflows::AbstractArray{<:Real, 1})
    if npv(cashflows, 0.0) < 0
        return 0.0
    end
    f(r) = npv(cashflows, r)
    rate = 0.0
    try
        rate = fzero(f, [0.0, 0.99])
    finally
        return round(rate, digits=2)
    end
end
