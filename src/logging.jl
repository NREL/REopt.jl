struct REoptLogger <: Logging.AbstractLogger
    d::Dict
    io::IO
end

REoptLogger() = REoptLogger(Dict(), stderr)

Logging.min_enabled_level(logger::REoptLogger) = Logging.Info

function Logging.shouldlog(logger::REoptLogger, level, _module, group, id)
    return true
 end

Logging.catch_exceptions(logger::REoptLogger) = true

function Logging.handle_message(logger::REoptLogger, lvl, msg, _mod, group, id, file, line; kwargs...)

    msglines = split(chomp(convert(String, string(msg))::String), '\n')
    msg1, rest = Iterators.peel(msglines)

    col = nothing
    if string(lvl)=="Error"
        col = :red
    elseif string(lvl)=="Warn"
        col = :light_yellow
    elseif string(lvl)=="Info"
        col = :cyan
    else
        col = :default
    end

    printstyled(logger.io, "┌ ", _mod, " | ", lvl, ": "; bold=true, color=col)
    printstyled(logger.io, msg1, "\n")
    for msg in rest
        println(logger.io, "│ ", msg)
    end
    for (key, val) in kwargs
        key === :maxlog && continue
        println(logger.io, "│   ", key, " = ", val)
    end
    println(logger.io, "└ @ ", _mod, " ", file, ":", line)

    if string(lvl) in ["Warn","Error"]
        if string(lvl) ∉ keys(logger.d) # key doesnt exists
            logger.d[string(lvl)] = Dict()
        end

        # Does the key for file exist?
        if occursin("\\", file) #windows
            splitter = "\\"
        else # unix/mac
            splitter = "/"
        end
        
        splt = split(file, splitter)
        f = join([splt[end-1], splt[end], line], "_")

        if f ∉ keys(logger.d[string(lvl)]) #file name doesnt exists
            logger.d[string(lvl)][f] = Any[]
        end

        push!(logger.d[string(lvl)][f], msg)
    end
end