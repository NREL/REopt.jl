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

function add_compressor_constraints(m, p; _n="") 

	##Constraint: Compressor takes hydrogen from LP storage to charge HP storage while consuming electricity
    if !isempty(p.s.storage.types.hydrogen_hp)
        @constraint(m, [ts in p.time_steps], 
            sum(m[Symbol("dvDischargeFromStorage"*_n)][b,ts] for b in p.s.storage.types.hydrogen_lp) 
            ==
            sum(p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.compressor)    
        )
        @constraint(m, [ts in p.time_steps], 
            sum(p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.compressor)
            ==
            sum(m[Symbol("dvProductionToStorage"*_n)][b,ts] for b in p.s.storage.types.hydrogen_hp) 
        )
        @constraint(m, [ts in p.time_steps_with_grid], 
            sum(p.s.compressor.efficiency_kwh_per_kg * p.production_factor[t, ts] * p.levelization_factor[t] * 
                m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.compressor)
            ==
            sum(m[Symbol("dvProductionToCompressor"*_n)][t, ts] for t in p.techs.elec)
            + m[Symbol("dvGridToCompressor"*_n)][ts]
            + sum(m[Symbol("dvStorageToCompressor"*_n)][b, ts] for b in p.s.storage.types.elec) 
        )
        @constraint(m, [ts in p.time_steps_without_grid], 
            sum(p.s.compressor.efficiency_kwh_per_kg * p.production_factor[t, ts] * p.levelization_factor[t] * 
                m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.compressor)
            ==
            sum(m[Symbol("dvProductionToCompressor"*_n)][t, ts] for t in p.techs.elec)
            + sum(m[Symbol("dvStorageToCompressor"*_n)][b, ts] for b in p.s.storage.types.elec) 
        )
    end

end

function add_electrolyzer_constraints(m, p; _n="") 

	##Constraint: Compressor takes hydrogen from LP storage to charge HP storage while consuming electricity
    if !isempty(t in p.techs.electrolyzer)
        @constraint(m, [ts in p.time_steps], 
            sum(p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.electrolyzer)
            ==
            sum(m[Symbol("dvProductionToStorage"*_n)][b,ts] for b in p.s.storage.types.hydrogen_lp) 
        )
        @constraint(m, [ts in p.time_steps_with_grid], 
            sum(p.s.electrolyzer.efficiency_kwh_per_kg * p.production_factor[t, ts] * p.levelization_factor[t] * 
                m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.electrolyzer)
            ==
            sum(m[Symbol("dvProductionToElectrolyzer"*_n)][t, ts] for t in p.techs.elec)
            + m[Symbol("dvGridToElectrolyzer"*_n)][ts]
            + sum(m[Symbol("dvStorageToElectrolyzer"*_n)][b, ts] for b in p.s.storage.types.elec) 
        )
        @constraint(m, [ts in p.time_steps_without_grid], 
            sum(p.s.electrolyzer.efficiency_kwh_per_kg * p.production_factor[t, ts] * p.levelization_factor[t] * 
                m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.electrolyzer)
            ==
            sum(m[Symbol("dvProductionToElectrolyzer"*_n)][t, ts] for t in p.techs.elec)
            + sum(m[Symbol("dvStorageToElectrolyzer"*_n)][b, ts] for b in p.s.storage.types.elec) 
        )
    end

end

# function add_production_constraints(m, p; _n="")
# 	# Constraint (4d): Electrical production sent to storage or export must be less than technology's rated production
#     if isempty(p.s.electric_tariff.export_bins)
#         @constraint(m, [t in p.techs.elec, ts in p.time_steps_with_grid],
#             sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types.elec)  
#             + m[Symbol("dvCurtail"*_n)][t, ts]
#             <= 
#             p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t, ts]
#         )
#     else
#         @constraint(m, [t in p.techs.elec, ts in p.time_steps_with_grid],
#             sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types.elec)  
#             + m[Symbol("dvCurtail"*_n)][t, ts]
#             + sum(m[Symbol("dvProductionToGrid"*_n)][t, u, ts] for u in p.export_bins_by_tech[t])
#             <= 
#             p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t, ts]
#         )
#     end

# 	# Constraint (4e): Electrical production sent to storage or curtailed must be less than technology's rated production - no grid
# 	@constraint(m, [t in p.techs.elec, ts in p.time_steps_without_grid],
#         sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types.elec)
#         + m[Symbol("dvCurtail"*_n)][t, ts]  
#         <= 
#         p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t, ts]
# 	)

# end
