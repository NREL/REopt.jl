
## Hosting documentation locally
You must `Pkg.dev REoptLite` in the docs Project for the docs to update using the following method. The python server does not pick up on changes dynamically so the process below must be repeated to show changes.
```bash
[~/.julia/dev/REoptLite/docs]
nlaws-> rm -rf build/

[~/.julia/dev/REoptLite/docs]
nlaws-> julia --project=. make.jl 
[ Info: SetupBuildDirectory: setting up build directory.
[ Info: Doctest: running doctests.
[ Info: ExpandTemplates: expanding markdown templates.
[ Info: CrossReferences: building cross-references.
[ Info: CheckDocument: running document checks.
[ Info: Populate: populating indices.
[ Info: RenderDocument: rendering document.
[ Info: HTMLWriter: rendering HTML pages.
┌ Warning: Documenter could not auto-detect the building environment Skipping deployment.
└ @ Documenter ~/.julia/packages/Documenter/bFHi4/src/deployconfig.jl:75

[~/.julia/dev/REoptLite/docs]
nlaws-> cd build/

[~/.julia/dev/REoptLite/docs/build]
nlaws-> python3 -m http.server --bind localhost
Serving HTTP on ::1 port 8000 (http://[::1]:8000/) ...
```

Alternatively, you can use `LiveServer.jl` to host the documentation locally:
```julia
[~/.julia/dev/REoptLite/docs]
nlaws-> julia --project=.
               _
   _       _ _(_)_     |  Documentation: https://docs.julialang.org
  (_)     | (_) (_)    |
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.6.1 (2021-04-23)
 _/ |\__'_|_|_|\__'_|  |  Official https://julialang.org/ release
|__/                   |

julia> using LiveServer
[ Info: Precompiling LiveServer [16fef848-5104-11e9-1b77-fb7a48bbb589]

julia> cd("build/")

julia> serve()
✓ LiveServer listening on http://localhost:8000/ ...
  (use CTRL+C to shut down)
```