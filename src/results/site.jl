# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************
"""
	add_site_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict)

Adds the Site results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs`.

Site results:
- `annual_renewable_electricity_kwh`
- `renewable_electricity_pct`
- `total_renewable_energy_pct`
- `year_one_emissions_tCO2`
- `year_one_emissions_tNOx`
- `year_one_emissions_tSO2`
- `year_one_emissions_tPM25`
- `year_one_emissions_from_fuelburn_tCO2`
- `year_one_emissions_from_fuelburn_tNOx`
- `year_one_emissions_from_fuelburn_tSO2`
- `year_one_emissions_from_fuelburn_tPM25`
- `lifecycle_emissions_cost_CO2`
- `lifecycle_emissions_cost_health`
- `lifecycle_emissions_tCO2`
- `lifecycle_emissions_tNOx`
- `lifecycle_emissions_tSO2`
- `lifecycle_emissions_tPM25`
- `lifecycle_emissions_from_fuelburn_tCO2`
- `lifecycle_emissions_from_fuelburn_tNOx`
- `lifecycle_emissions_from_fuelburn_tSO2`
- `lifecycle_emissions_from_fuelburn_tPM25`

calculated in combine_results function if BAU scenario is run:
- `lifecycle_emissions_reduction_CO2_pct`

"""
function add_site_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
	r = Dict{String, Any}()

	# renewable elec
	r["annual_renewable_electricity_kwh"] = round(value(m[:AnnualREEleckWh]), digits=2)
	r["renewable_electricity_pct"] = round(value(m[:AnnualREEleckWh])/value(m[:AnnualEleckWh]), digits=6)

	# total renewable 
	add_re_tot_calcs(m,p)
	r["total_renewable_energy_pct"] = round(value(m[:AnnualRETotkWh])/value(m[:AnnualTotkWh]), digits=6)
	
	# pass through for breakeven cost of CO2 calculation:
	r["include_climate_in_objective"] = p.s.settings.include_climate_in_objective
	r["pwf_emissions_cost_CO2_grid"] = p.pwf_emissions_cost["CO2_grid"]
	r["pwf_emissions_cost_CO2_onsite"] = p.pwf_emissions_cost["CO2_onsite"]

	# Year 1 Emissions results at Site level
	r["year_one_emissions_tCO2"] = round(value(m[:EmissionsYr1_Total_LbsCO2]/TONNES_TO_LBS), digits=2)
	r["year_one_emissions_tNOx"] = round(value(m[:EmissionsYr1_Total_LbsNOx]/TONNES_TO_LBS), digits=2)
	r["year_one_emissions_tSO2"] = round(value(m[:EmissionsYr1_Total_LbsSO2]/TONNES_TO_LBS), digits=2)
	r["year_one_emissions_tPM25"] = round(value(m[:EmissionsYr1_Total_LbsPM25]/TONNES_TO_LBS), digits=2)

	r["year_one_emissions_from_fuelburn_tCO2"] = round(value(m[:yr1_emissions_onsite_fuel_lbs_CO2]/TONNES_TO_LBS), digits=2)
	r["year_one_emissions_from_fuelburn_tNOx"] = round(value(m[:yr1_emissions_onsite_fuel_lbs_NOx]/TONNES_TO_LBS), digits=2)
	r["year_one_emissions_from_fuelburn_tSO2"] = round(value(m[:yr1_emissions_onsite_fuel_lbs_SO2]/TONNES_TO_LBS), digits=2)
	r["year_one_emissions_from_fuelburn_tPM25"] = round(value(m[:yr1_emissions_onsite_fuel_lbs_PM25]/TONNES_TO_LBS), digits=2)

	# Lifecycle emissions results at Site level
	if !isnothing(p.s.site.bau_grid_emissions_lb_CO2_per_year)
		r["lifecycle_emissions_reduction_CO2_pct"] = round(value(1-m[:Lifecycle_Emissions_Lbs_CO2]/m[:Lifecycle_Emissions_Lbs_CO2_BAU]), digits=6)
	end
	r["lifecycle_emissions_cost_CO2"] = round(value(m[:Lifecycle_Emissions_Cost_CO2]), digits=2)
	r["lifecycle_emissions_cost_health"] = round(value(m[:Lifecycle_Emissions_Cost_Health]), digits=2)

	r["lifecycle_emissions_tCO2"] = round(value(m[:Lifecycle_Emissions_Lbs_CO2]/TONNES_TO_LBS), digits=2)
	r["lifecycle_emissions_tNOx"] = round(value(m[:Lifecycle_Emissions_Lbs_NOx]/TONNES_TO_LBS), digits=2)
	r["lifecycle_emissions_tSO2"] = round(value(m[:Lifecycle_Emissions_Lbs_SO2]/TONNES_TO_LBS), digits=2)
	r["lifecycle_emissions_tPM25"] = round(value(m[:Lifecycle_Emissions_Lbs_PM25]/TONNES_TO_LBS), digits=2)

	r["lifecycle_emissions_from_fuelburn_tCO2"] = round(value(m[:Lifecycle_Emissions_Lbs_CO2_fuelburn]/TONNES_TO_LBS), digits=2)
	r["lifecycle_emissions_from_fuelburn_tNOx"] = round(value(m[:Lifecycle_Emissions_Lbs_NOx_fuelburn]/TONNES_TO_LBS), digits=2)
	r["lifecycle_emissions_from_fuelburn_tSO2"] = round(value(m[:Lifecycle_Emissions_Lbs_SO2_fuelburn]/TONNES_TO_LBS), digits=2)
	r["lifecycle_emissions_from_fuelburn_tPM25"] = round(value(m[:Lifecycle_Emissions_Lbs_PM25_fuelburn]/TONNES_TO_LBS), digits=2)

	d["Site"] = r
end