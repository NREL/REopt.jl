struct str
    str_attr::Real

    function str(;
        func_arg::Union{Real, AbstractVector{Real}} = 1.0
    )
        str_attr = 2 * func_arg
    
        new(
            str_attr
        )
    end
end