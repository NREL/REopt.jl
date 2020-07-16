# REoptLite Julia package
This package is currently under development and only has a subset of capabilities of the REopt Lite model used in the [REopt Lite API](github.com/NREL/REopt-Lite-API). For example, the Wind model, tiered electric utility tariffs, and piecewise linear cost curves are not yet modeled in this code. However this code is easier to use than the API (only dependencies are Julia and a solver) and has a novel model for uncertain outages.


## Uncertain outages
The full details of the model will be published in _Laws et al. 2020, Cost-Optimal Microgrid Planning Under Uncertain Grid Reliability, [Draft]_. In brief, the model is set up to minimize the maximum expected outage cost (while minimizing the lifecycle cost of energy including utility tariff costs), where the maximum is taken over outage start times, and the expectation is taken over outage durations.