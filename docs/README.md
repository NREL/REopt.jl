
## Hosting documentation locally
You must `Pkg.dev REoptLite` in the docs Project for the docs to update using the following method. The python server does not pick up on changes dynamically so the process below must be repeated to show changes.
```sh
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