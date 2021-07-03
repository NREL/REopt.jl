# MPC Examples
The MPC capability provided by `REoptLite` is essentially the optimal sizing and dispatch capability that `REoptLite` is commonly used for, but with the sizing problem removed. Also, the MPC model can be built for an arbitrary time length, or "horizon" (whereas a `REoptLite` model always includes an entire calendar year). The MPC model also requires the user to provide load and resource forecasts as inputs (whereas the typical `REoptLite` model allows one to use built-in load profiles as well as other API's such as PVWatts for the solar resource).

```@example
using REoptLite, JuMP, Cbc
model = Model(Cbc.Optimizer)
results = run_mpc(model, "./test/scenarios/mpc.json")
```
See [mpc.json](https://github.com/NREL/REoptLite/blob/master/test/scenarios/mpc.json) for details on the Scenario.