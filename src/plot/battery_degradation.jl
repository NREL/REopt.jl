




function efc(d)
    if "EFC" in keys(d["Storage"])
        return d["Storage"]["EFC"]
    end
    # TODO use REoptInputs for initial SOC 
    power = diff(append!([0.5], d["Storage"]["year_one_soc_series_pct"]))
    abs_power = abs.(power)
    efc = zeros(365)
    # TODO handle time resolution other than hourly
    for d in 1:365
        ts0 = Int(round((24 * (d - 1) + 1)))
        tsF = Int(round(24 * d))
        efc[d] = sum(abs_power[ts0:tsF])/2
    end
    return efc
end


function plot_violin_compare_soc_efc(d1::Dict, d2::Dict; title="Violin distribution of SOC and EFC")

    soc1 = d1["Storage"]["year_one_soc_series_pct"]
    soc2 = d2["Storage"]["year_one_soc_series_pct"]

    efc1 = efc(d1)
    efc2 = efc(d2)

    traces = [
        PlotlyJS.violin(
            y=soc1, 
            side="negative", 
            x=repeat(["SOC"], length(soc1)), 
            spanmode="hard",
            points=false,
            # pointpos=-1.5,
            # box_visible=true,
            # legendgroup="No", 
            # scalegroup="No"
        ), 
        PlotlyJS.violin(
            y=soc2, 
            side="positive", 
            x=repeat(["SOC"], length(soc2)), 
            spanmode="hard",
            points=false,
            # pointpos=1.5,
            # box_visible=true,
            # legendgroup="No", 
            # scalegroup="No"
        ), 
        PlotlyJS.violin(
            y=efc1, 
            side="negative", 
            x=repeat(["EFC"], length(efc1)), 
            spanmode="hard",
            points=false,
            # pointpos=-1.5,
            # box_visible=true,
            # legendgroup="No", 
            # scalegroup="No"
        ), 
        PlotlyJS.violin(
            y=efc2, 
            side="positive", 
            x=repeat(["EFC"], length(efc2)), 
            spanmode="hard",
            points=false,
            # pointpos=1.5,
            # box_visible=true,
            # legendgroup="No", 
            # scalegroup="No"
        ), 
    ]

    layout = PlotlyJS.Layout(
        title_text = title
    )

    PlotlyJS.plot(traces, layout)
end



