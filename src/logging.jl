struct REoptLogger <: Logging.AbstractLogger
    d::Dict
    io::IO
end

REoptLogger() = REoptLogger(Dict(), stderr)

Logging.min_enabled_level(logger::REoptLogger) = Logging.BelowMinLevel

function Logging.shouldlog(logger::REoptLogger, level, _module, group, id)
    return true
 end

Logging.catch_exceptions(logger::REoptLogger) = true

function Logging.handle_message(logger::REoptLogger, lvl, msg, _mod, group, id, file, line; kwargs...)

    msglines = split(chomp(convert(String, string(msg))::String), '\n')
    msg1, rest = Iterators.peel(msglines)
    println(logger.io, "┌ ", _mod, " | ", lvl, ": ", msg1)
    for msg in rest
        println(logger.io, "│ ", msg)
    end
    for (key, val) in kwargs
        key === :maxlog && continue
        println(logger.io, "│   ", key, " = ", val)
    end
    println(logger.io, "└ @ ", _mod, " ", file, ":", line)

    if string(lvl) ∉  ["Warn","Error"]
        nothing
    else
        if string(lvl) ∉ keys(logger.d) # key doesnt exists
            logger.d[string(lvl)] = Dict()
        else
            nothing #exists
        end

        # Does the key for file exist?
        filename = join(split(file, '\\')[end-2:end], "_")

        if filename ∉ keys(logger.d[string(lvl)]) #file name doesnt exists
            logger.d[string(lvl)][filename] = Any[]
        else
            nothing
        end

        push!(logger.d[string(lvl)][filename], msg)
    end
end