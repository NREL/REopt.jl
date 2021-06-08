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
using Test

#=
To test with only one solver:
julia> using Pkg
julia> Pkg.test("REoptLite"; test_args=["Cbc"])

nlaws 200721: only running Cbc tests here b/c cannot get CPLEX and Xpress licences on to Github
    servers (runtests.jl is automated in Github Actions with ci.yml).

TODO: combine tests into one file and pass in Solver
=#

@testset "REoptLite.jl" begin
    # if isempty(ARGS) || "all" in ARGS
    #     all_tests = true
    # else
    #     all_tests = false
    # end
    # if all_tests || "CPLEX" in ARGS
    #     @testset "test_with_cplex" begin
    #         include("test_with_cplex.jl")
    #     end
    # end
    # if all_tests || "Xpress" in ARGS
    #     @testset "test_with_xpress" begin
    #         include("test_with_xpress.jl")
    #     end
    # end
    # if all_tests || "Cbc" in ARGS
        @testset "test_with_cbc" begin
            include("test_with_cbc.jl")
        end
    # end
end
