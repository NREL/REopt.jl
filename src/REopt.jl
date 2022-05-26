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
module REopt

export
    Scenario,
    BAUScenario,
    REoptInputs,
    run_reopt,
    build_reopt!,
    reopt_results,
    simulate_outages,
    add_variables!,
    add_objective!,
    LinDistFlow,
    MPCScenario,
    MPCInputs,
    run_mpc,
    build_mpc!

import HTTP
import JSON
using LinDistFlow  # required to export LinDistFlow
import LinDistFlow 
const LDF = LinDistFlow
using JuMP
using JuMP.Containers: DenseAxisArray
using Logging
using DelimitedFiles
using Dates
import MathOptInterface
import Dates: daysinmonth, Date, isleapyear
import DelimitedFiles: readdlm
const MOI = MathOptInterface
using Shapefile
using ArchGDAL
using Roots: fzero  # for IRR
global hdl = nothing

const EXISTING_BOILER_EFFICIENCY = 0.8

const GAL_PER_M3 = 264.172  # [gal/m^3]
const KWH_PER_GAL_DIESEL = 40.7  # [kWh/gal_diesel]
const KWH_PER_MMBTU = 293.07107  # [kWh/mmbtu]
const KWH_THERMAL_PER_TONHOUR = 3.51685
const TONNE_PER_LB = 1/2204.62  # [tonne/lb]

include("keys.jl")
include("core/types.jl")
include("core/utils.jl")

include("core/settings.jl")
include("core/site.jl")
include("core/financial.jl")
include("core/pv.jl")
include("core/wind.jl")
include("core/energy_storage/storage.jl")
include("core/energy_storage/electric_storage.jl")
include("core/energy_storage/thermal_storage.jl")
include("core/generator.jl")
include("core/doe_commercial_reference_building_loads.jl")
include("core/electric_load.jl")
include("core/existing_boiler.jl")
include("core/existing_chiller.jl")
include("core/absorption_chiller.jl")
include("core/flexible_hvac.jl")
include("core/heating_cooling_loads.jl")
include("core/electric_utility.jl")
include("core/prodfactor.jl")
include("core/urdb.jl")
include("core/electric_tariff.jl")
include("core/chp.jl")
include("core/thermosyphon.jl")
include("core/scenario.jl")
include("core/bau_scenario.jl")
include("core/reopt_inputs.jl")
include("core/bau_inputs.jl")
include("core/cost_curve.jl")

include("constraints/outage_constraints.jl")
include("constraints/storage_constraints.jl")
include("constraints/flexible_hvac.jl")
include("constraints/load_balance.jl")
include("constraints/tech_constraints.jl")
include("constraints/electric_utility_constraints.jl")
include("constraints/generator_constraints.jl")
include("constraints/cost_curve_constraints.jl")
include("constraints/production_incentive_constraints.jl")
include("constraints/thermal_tech_constraints.jl")
include("constraints/chp_constraints.jl")
include("constraints/operating_reserve_constraints.jl")
include("constraints/battery_degradation.jl")
include("constraints/thermosyphon_constraints.jl")

include("mpc/structs.jl")
include("mpc/scenario.jl")
include("mpc/inputs.jl")
include("mpc/constraints.jl")

include("core/techs.jl")

include("results/results.jl")
include("results/electric_tariff.jl")
include("results/electric_utility.jl")
include("results/proforma.jl")
include("results/financial.jl")
include("results/generator.jl")
include("results/pv.jl")
include("results/electric_storage.jl")
include("results/thermal_storage.jl")
include("results/outages.jl")
include("results/wind.jl")
include("results/electric_load.jl")
include("results/existing_boiler.jl")
include("results/existing_chiller.jl")
include("results/absorption_chiller.jl")
include("results/chp.jl")
include("results/flexible_hvac.jl")
include("results/thermosyphon.jl")

include("core/reopt.jl")
include("core/reopt_multinode.jl")

include("outagesim/outage_simulator.jl")

include("lindistflow/extend.jl")

include("mpc/results.jl")
include("mpc/model.jl")

end
