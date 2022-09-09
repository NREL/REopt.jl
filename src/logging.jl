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
    println(logger.io, "┌ ", lvl, ": ", msg1)
    for msg in rest
        println(logger.io, "│ ", msg)
    end
    for (key, val) in kwargs
        key === :maxlog && continue
        println(logger.io, "│   ", key, " = ", val)
    end
    println(logger.io, "└ @ ", _mod, " ", file, ":", line)

    # Ensure info, warn and error keys exist
    if string(lvl) in keys(logger.d)
        # Ensure a key exists for all file names with errors
        if string(file) in keys(logger.d[string(lvl)])
            nothing
        else
            logger.d[string(lvl)][join(split(file, '\\')[end-2:end], "_")] = []
        end
        else
            logger.d[string(lvl)]=Dict()
            logger.d[string(lvl)][join(split(file, '\\')[end-2:end], "_")] = []
    end
    push!(logger.d[string(lvl)][join(split(file, '\\')[end-2:end], "_")], msglines)
end