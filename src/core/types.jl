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
abstract type AbstractTech end
abstract type AbstractStorage end
abstract type AbstractGenerator end

abstract type ExistsNew end
abstract type Exists <: ExistsNew end
abstract type New <: ExistsNew end


"""
pv_exists = PV{Exists}()
pv_exists.cost == 0

pv_new = PV{New}()
pv_new.cost == 100

pv_new_expensive = PV{New}(cost=1000)
pv_new_expensive.cost == 1000
"""
# Base.@kwdef struct PV{T <: ExistsNew}
#     cost::Float64=100
# end

# PV{Exists}() = PV{Exists}(cost=0)





# TODO create Tech template? using parametric type?
# @enum TechClass PV Generator Wind

# struct Tech{T <: TechClass} <: AbstractTech
#     class::T
# end

# _get_REopt_x_args will dispatch on Array{Tech} ?imp

#=
- What is the core of the REopt model?
    - i.e. what is base model: it doesn't have to include Utility (MG design), nor storage, but it 
    has to have at least one Tech? Does have to have some costs, otherwise what is it minimizing?
    Could be minimizing emissions or maximizing %RE instead of min $ though. How to make it as flexible
    as possible?
    - maybe the base model dispatches on inputs, and thus we can have different base models.
    - goal is to create boilier plate models though.
- Model should use concrete types' data, rather than duplicating the data outside and inside the model
    - attach model variables to structs?
=#