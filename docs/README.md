# REoptLite.jl Documentation Guidance
See the [Documenter.jl documentation](https://juliadocs.github.io/Documenter.jl/stable/)

## Simplified Steps
1. Modify doc strings on exported structs and functions (or add doc strings to new structs or functions and export them from the module).
2. Make the documents to make sure that your changes will build on the github server:
```sh
bash-> julia --project=docs/
```
```julia
julia> include("docs/make.jl")
[ Info: SetupBuildDirectory: setting up build directory.
[ Info: Doctest: running doctests.
[ Info: ExpandTemplates: expanding markdown templates.
[ Info: CrossReferences: building cross-references.
[ Info: CheckDocument: running document checks.
[ Info: Populate: populating indices.
[ Info: RenderDocument: rendering document.
[ Info: HTMLWriter: rendering HTML pages.
┌ Warning: Documenter could not auto-detect the building environment Skipping deployment.
└ @ Documenter ~/.julia/packages/Documenter/lul8Y/src/deployconfig.jl:75
```
The `Warning` is expected since there is no environment to deploy the documents to when building locally.

3. Only pushes to master branch will trigger the public documents to update, but you can preview your changes locally using python:
```
cd docs/build
python3 -m http.server --bind localhost
```