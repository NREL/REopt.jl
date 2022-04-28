
## Hosting documentation locally
You must `Pkg.dev REopt` in the docs Project for the docs to update using the following method. The python server does not pick up on changes dynamically so the process below must be repeated to show changes.
```bash
[~/.julia/dev/REopt/docs]
nlaws-> rm -rf build/

[~/.julia/dev/REopt/docs]
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

[~/.julia/dev/REopt/docs]
nlaws-> cd build/

[~/.julia/dev/REopt/docs/build]
nlaws-> python3 -m http.server --bind localhost
Serving HTTP on ::1 port 8000 (http://[::1]:8000/) ...
```

Alternatively, you can use `LiveServer.jl` to host the documentation locally:
```julia
[~/.julia/dev/REopt/docs]
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

## Fixing a broken docs build or updating docs without creating a new release
From the Documenter.jl documentation:

"It can happen that, for one reason or another, the documentation for a tagged version of your package fails to deploy and a fix would require changes to the source code (e.g. a misconfigured make.jl). However, as registered tags should not be changed, you can not simply update the original tag (e.g. v1.2.3) with the fix."

"In this situation, you can manually create and push a tag for the commit with the fix that has the same version number, but also some build metadata (e.g. v1.2.3+doc1). For Git, this is a completely different tag, so it won't interfere with anything. But when Documenter runs on this tag, it will ignore the build metadata and deploy the docs as if they were for version v1.2.3."

After making a commit to fix the docs, tag that commit with:
```
git tag -a vX.X.X+docsfix -m "<description of version>" <commit hash>
```
After pushing the docs will be built via Actions.