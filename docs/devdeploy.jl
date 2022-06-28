using LiveServer

"""
Run this script to locally host 
NOTE you have to dev REopt in the docs environment to get local changes. 

e.g. 
```julia
julia> cd("docs")
(REopt) pkg> activate .
(REopt) pkg> dev REopt
(docs) pkg> st
      Status `~/.julia/dev/REopt/docs/Project.toml`
  [e30172f5] Documenter v0.26.3
  [4076af6c] JuMP v1.1.1
  [16fef848] LiveServer v0.8.3
  [d36ad4e8] REopt v0.16.2 `~/.julia/dev/REopt`
```
"""
function devbuildserve()
    rm("build", force=true, recursive=true)
    include("make.jl")
    cd("build")
    serve()
end

devbuildserve()