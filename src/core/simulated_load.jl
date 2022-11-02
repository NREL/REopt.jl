function simulated_load(d::Dict)
    try
        latitude = get(d, "latitude", @error "latitude must be provided")
        longitude = get(d, "longitude", @error "longitude must be provided")
        load_type = get(d, "load_type", nothing)

        if haskey(d, "doe_reference_name") && typeof(d["doe_reference_name"]) != Vector{String} 
            doe_reference_name = [d["doe_reference_name"]]
        elseif haskey(d, "doe_reference_name") && haskey(d, "percent_share_list")
            if length(percent_share_list) != length(doe_reference_name)
                @error "The number of percent_share entries does not match that of the number of doe_reference_name entries"
            end
        else
            doe_reference_name = nothing
            percent_share_list = nothing
        end

        # When wanting cooling profile based on building type(s) for cooling, need separate cooling building(s)
        if haskey(d, "cooling_doe_ref_name") && typeof(d["cooling_doe_ref_name"]) != Vector{String} 
            cooling_doe_ref_name = d["cooling_doe_ref_name"]
            cooling_pct_share_list = [100.0]
        elseif haskey(d, "cooling_doe_ref_name") && haskey(d, "cooling_pct_share_list")
            if length(cooling_pct_share_list) != length(cooling_doe_ref_name)
                @error "The number of cooling_pct_share entries does not match that of the number of cooling_doe_ref_name entries"
            end
        else
            cooling_doe_ref_name = nothing
            cooling_pct_share_list = nothing
        end

        if isnothing(doe_reference_name) && !isnothing(cooling_doe_ref_name)
            doe_reference_name = cooling_doe_ref_name
            percent_share_list = cooling_pct_share_list
        end

        if !isnothing(doe_reference_name)
            for drn in doe_reference_name
                if drn not in default_buildings
                    @error "Invalid doe_reference_name - $doe_reference_name. Select from the following: $default_buildings"
                end
            end
        end

        if isnothing(load_type)
            load_type = "electric"
        end

        if latitude > 90 || latitude < -90
            @error "latitude $latitude is out of acceptable range (-90 <= latitude <= 90)"
        end

        if longitude > 180 || longitude < -180
            @error "longitude $longitude is out of acceptable range (-180 <= longitude <= 180)"
        end

        if load_type not in ["electric","heating","cooling"]
            @error "load_type parameter must be one of the following: 'electric', 'heating', or 'cooling'."
                             " If load_type is not specified, 'electric' is assumed."
        end

        # The following is possibly used in both load_type == "electric" and "cooling", so have to bring it out of those if-statements
        chiller_cop = get(d, "chiller_cop", nothing)

        if !isnothing(get(d, "max_thermal_factor_on_peak_load", nothing))
            max_thermal_factor_on_peak_load = d["max_thermal_factor_on_peak_load"]
        else
            max_thermal_factor_on_peak_load = 1.25
        end

        if load_type == "electric"
            for key in keys(d)
                if occursin("_mmbtu", key) || occursin("_ton", key) || occursin("_fraction", key)
                    @error "Invalid key $key for load_type=electric"
                end
            if isnothing(doe_reference_name)
                @error "Please supply a doe_reference_name and optionally scaling parameters (annual_kwh or monthly_totals_kwh)."
            end
            #Annual loads
            if !("annual_kwh" in keys(d))
                annual_kwh = nothing
            end
            #Monthly loads
            if !isnothing(get(d, "monthly_totals_kwh", nothing))
                bad_index = []
                for (i, kwh) in enumerate(monthly_totals_kwh)
                    if isnothing(kwh)
                        append!(bad_index, i)
                    end
                end
                if length(bad_index) > 0
                    @error "monthly_totals_kwh must contain a value for each month, and it is null for these months: $bad_index"
                end
            else
                monthly_totals_kwh = []
            end

            # Build dependent inputs for electric load
            elec_load_inputs = Dict{Symbol, Any}()
            if length(doe_reference_name) > 1
                elec_load_inputs[:blended_doe_reference_names] = doe_reference_name
                elec_load_inputs[:blended_doe_reference_percents] = percent_share_list
            else
                elec_load_inputs[:doe_reference_name] = doe_reference_name[1]
            end

            electric_load = ElectricLoad(; elec_load_inputs...,
                                    latitude=latitude,
                                    longitude=longitude,
                                    annual_kwh=annual_kwh,
                                    monthly_totals_kwh=monthly_totals_kwh
                                )

            # Get the default cooling portion of the total electric load (used when we want cooling load without annual_tonhour input)
            if !isnothing(cooling_doe_ref_name)
                # Build dependent inputs for cooling load
                cooling_load_inputs = Dict{Symbol, Any}()
                if length(cooling_doe_ref_name) > 1
                    cooling_load_inputs[:blended_doe_reference_names] = cooling_doe_ref_name
                    cooling_load_inputs[:blended_doe_reference_percents] = cooling_pct_share_list
                else
                    cooling_load_inputs[:doe_reference_name] = cooling_doe_ref_name[1]
                end
                cooling_load = CoolingLoad(; cooling_load_inputs...,
                                            city=electric_load.city,
                                            latitude=latitude,
                                            longitude=longitude,
                                            site_electric_load_profile=electric_load.loads_kw,
                                            existing_chiller_cop=chiller_cop,
                                            existing_chiller_max_thermal_factor_on_peak_load=max_thermal_factor_on_peak_load
                                    )

                modified_fraction = []
                for (i, building) in enumerate(cooling_doe_ref_name)
                    default_fraction = get_default_fraction_of_total_electric(electric_load.city, building, latitude, longitude, electric_load.year)
                    modified_fraction = default_fraction * cooling_pct_share_list[i] / 100.0
                end

                cooling_load_thermal_ton = round.(cooling_load.loads_kw_thermal ./ KWH_THERMAL_PER_TONHOUR, digits=3)
                cooling_defaults_dict = Dict([
                                            ("loads_ton", cooling_load_thermal_ton),
                                            ("annual_tonhour", sum(cooling_load_thermal_ton)),
                                            ("chiller_cop", round(cooling_load.chiller_cop, digits=3)),
                                            ("min_ton", minimum(cooling_load_thermal_ton)),
                                            ("mean_ton", sum(cooling_load_thermal_ton) / length(cooling_load_thermal_ton)),
                                            ("max_ton", maximum(cooling_load_thermal_ton)),
                                            ("fraction_of_total_electric_profile", round.(modified_fraction, digits=9))
                                            ])
            else
                cooling_defaults_dict = Dict()
            end

            electric_loads_kw = round.(electric_load.loads_kw, digits=3)

            response = Dict([
                            ("loads_kw", electric_loads_kw),
                            ("annual_kwh", sum(electric_loads_kw)),
                            ("min_kw", minimum(electric_loads_kw)),
                            ("mean_kw", sum(electric_loads_kw) / length(electric_loads_kw)),
                            ("max_kw", maximum(electric_loads_kw)),
                            ("cooling_defaults", cooling_defaults_dict)
                            ])

            return response

        if load_type == "heating"
            for key in keys(d)
                if occursin("_kw", key) || occursin("_ton", key)
                    @error "Invalid key $key for load_type=heating"
                end
            end
            if isnothing(doe_reference_name)
                @error "Please supply a doe_reference_name and optional scaling parameters (annual_mmbtu or monthly_mmbtu)."
            end
            #Annual loads
            if !("annual_mmbtu" in keys(d))
                annual_mmbtu = nothing
            end
            #Monthly loads
            if !isnothing(get(d, "monthly_mmbtu", nothing))
                bad_index = []
                for (i, mmbtu) in enumerate(monthly_mmbtu)
                    if isnothing(mmbtu)
                        append!(bad_index, i)
                    end
                end
                if length(bad_index) > 0
                    @error "monthly_mmbtu must contain a value for each month, and it is null for these months: $bad_index"
                end
            else
                monthly_mmbtu = []
            end
            # Addressable heating load
            if !isnothing(get(d, "addressable_load_fraction", nothing))
                bad_index = []
                for (i, frac) in enumerate(addressable_load_fraction)
                    if isnothing(frac)
                        append!(bad_index, i)
                    end
                end
                if length(bad_index) > 0
                    @error "addressable_load_fraction must contain a value for each month, and it is null for these months: $bad_index"
                end
            else
                addressable_load_fraction = 1.0
            end

            kwargs_heating = Dict{Symbol, Any}
            kwargs_heating[:addressable_load_fraction] = addressable_load_fraction

            # TODO left off here

            if "space_heating_fraction_of_heating_load" in request.GET.keys():
                space_heating_fraction_of_heating_load = [float(request.GET.get("space_heating_fraction_of_heating_load"))]
                kwargs_heating["space_heating_fraction_of_heating_load"] = space_heating_fraction_of_heating_load

            b_space = LoadProfileBoilerFuel(load_type="SpaceHeating", dfm=None, latitude=latitude, longitude=longitude, doe_reference_name=doe_reference_name,
                           annual_mmbtu=annual_mmbtu, monthly_mmbtu=monthly_mmbtu, time_steps_per_hour=1,
                           percent_share=percent_share_list, **kwargs_heating)

            b_dhw = LoadProfileBoilerFuel(load_type="DHW", dfm=None, latitude=latitude, longitude=longitude, doe_reference_name=doe_reference_name,
                           annual_mmbtu=annual_mmbtu, monthly_mmbtu=monthly_mmbtu, time_steps_per_hour=1,
                           percent_share=percent_share_list, **kwargs_heating)

            lp = [b_space.load_list[i] + b_dhw.load_list[i] for i in range(len(b_space.load_list))]

            response = JsonResponse(
                {"loads_mmbtu": [round(ld, 3) for ld in lp],
                 "annual_mmbtu": b_space.annual_mmbtu + b_dhw.annual_mmbtu,
                 "min_mmbtu": round(min(lp), 3),
                 "mean_mmbtu": round(sum(lp) / len(lp), 3),
                 "max_mmbtu": round(max(lp), 3),
                 "space_loads_mmbtu": [round(ld, 3) for ld in b_space.load_list],
                 "space_annual_mmbtu": b_space.annual_mmbtu,
                 "space_min_mmbtu": round(min(b_space.load_list), 3),
                 "space_mean_mmbtu": round(sum(b_space.load_list) / len(b_space.load_list), 3),
                 "space_max_mmbtu": round(max(b_space.load_list), 3),
                 "dhw_loads_mmbtu": [round(ld, 3) for ld in b_dhw.load_list],
                 "dhw_annual_mmbtu": b_dhw.annual_mmbtu,
                 "dhw_min_mmbtu": round(min(b_dhw.load_list), 3),
                 "dhw_mean_mmbtu": round(sum(b_dhw.load_list) / len(b_dhw.load_list), 3),
                 "dhw_max_mmbtu": round(max(b_dhw.load_list), 3),
                 }
                )

            return response

        if load_type == "cooling":
            for key in request.GET.keys():
                if ("_kw" in key) or ("_mmbtu" in key):
                    raise ValueError("Invalid key {} for load_type=cooling".format(key))

            if request.GET.get("annual_fraction") is not None:  # annual_kwh is optional. if not provided, then DOE reference value is used.
                annual_fraction = float(request.GET["annual_fraction"])
                lp = [annual_fraction]*8760
                response = JsonResponse(
                    {"loads_fraction": [round(ld, 3) for ld in lp],
                     "annual_fraction": round(sum(lp) / len(lp), 3),
                     "min_fraction": round(min(lp), 3),
                     "mean_fraction": round(sum(lp) / len(lp), 3),
                     "max_fraction": round(max(lp), 3),
                     }
                    )
                return response

            if (request.GET.get("monthly_fraction") is not None) or (request.GET.get("monthly_fraction[0]") is not None):  # annual_kwh is optional. if not provided, then DOE reference value is used.
                if "monthly_fraction" in request.GET.keys():
                    string_array = request.GET.get("monthly_fraction")
                    monthly_fraction = [float(v) for v in string_array.strip("[]").split(",")]
                elif "monthly_fraction[0]" in request.GET.keys():
                    monthly_fraction  = [request.GET.get("monthly_fraction[{}]".format(i)) for i in range(12)]
                    if None in monthly_fraction:
                        bad_index = monthly_fraction.index(None)
                        raise ValueError("monthly_fraction must contain a value for each month. {} is null".format("monthly_fraction[{}]".format(bad_index)))
                    monthly_fraction = [float(i) for i in monthly_fraction]
                days_in_month = {   0:31,
                                    1:28,
                                    2:31,
                                    3:30,
                                    4:31,
                                    5:30,
                                    6:31,
                                    7:31,
                                    8:30,
                                    9:31,
                                    10:30,
                                    11:31}
                lp = []
                for i in range(12):
                    lp += [monthly_fraction[i]] * days_in_month[i] *24
                response = JsonResponse(
                    {"loads_fraction": [round(ld, 3) for ld in lp],
                     "annual_fraction": round(sum(lp) / len(lp), 3),
                     "min_fraction": round(min(lp), 3),
                     "mean_fraction": round(sum(lp) / len(lp), 3),
                     "max_fraction": round(max(lp), 3),
                     }
                    )
                return response

            if doe_reference_name is not None:
                #Annual loads
                if "annual_tonhour" in request.GET.keys():
                    annual_tonhour = float(request.GET.get("annual_tonhour"))
                else:
                    annual_tonhour = None
                #Monthly loads
                if "monthly_tonhour" in request.GET.keys():
                    string_array = request.GET.get("monthly_tonhour")
                    monthly_tonhour = [float(v) for v in string_array.strip("[]").split(",")]
                elif "monthly_tonhour[0]" in request.GET.keys():
                    monthly_tonhour  = [request.GET.get("monthly_tonhour[{}]".format(i)) for i in range(12)]
                    if None in monthly_tonhour:
                        bad_index = monthly_tonhour.index(None)
                        raise ValueError("monthly_tonhour must contain a value for each month. {} is null".format("monthly_tonhour[{}]".format(bad_index)))
                    monthly_tonhour = [float(i) for i in monthly_tonhour]
                else:
                    monthly_tonhour = None

                if not annual_tonhour and not monthly_tonhour:
                    raise ValueError("Use load_type=electric to get cooling load for buildings with no annual_tonhour or monthly_tonhour input (response.cooling_defaults)")

                c = LoadProfileChillerThermal(dfm=None, latitude=latitude, longitude=longitude, doe_reference_name=doe_reference_name,
                               annual_tonhour=annual_tonhour, monthly_tonhour=monthly_tonhour, time_steps_per_hour=1, annual_fraction=None,
                               monthly_fraction=None, percent_share=percent_share_list, max_thermal_factor_on_peak_load=max_thermal_factor_on_peak_load,
                               chiller_cop=chiller_cop)

                lp = c.load_list

                response = JsonResponse(
                    {"loads_ton": [round(ld/KWH_THERMAL_PER_TONHOUR, 3) for ld in lp],
                     "annual_tonhour": round(c.annual_kwht/KWH_THERMAL_PER_TONHOUR,3),
                     "chiller_cop": c.chiller_cop,
                     "min_ton": round(min(lp)/KWH_THERMAL_PER_TONHOUR, 3),
                     "mean_ton": round((sum(lp)/len(lp))/KWH_THERMAL_PER_TONHOUR, 3),
                     "max_ton": round(max(lp)/KWH_THERMAL_PER_TONHOUR, 3),
                     }
                    )
                return response
            else:
                raise ValueError("Please supply a doe_reference_name and optional scaling parameters (annual_tonhour or monthly_tonhour), or annual_fraction, or monthly_fraction.")

    except KeyError as e:
        return JsonResponse({"Error. Missing": str(e.args[0])}, status=400)

    except ValueError as e:
        return JsonResponse({"Error": str(e.args[0])}, status=400)

    except Exception:

        exc_type, exc_value, exc_traceback = sys.exc_info()
        debug_msg = "exc_type: {}; exc_value: {}; exc_traceback: {}".format(exc_type, exc_value.args[0],
                                                                            tb.format_tb(exc_traceback))
        log.error(debug_msg)
        return JsonResponse({"Error": "Unexpected Error. Please check your input parameters and contact reopt@nrel.gov if problems persist."}, status=500)
