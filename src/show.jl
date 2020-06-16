# Simple "print"-like rendering, use "{ ... }" brackets for compactness
function Base.show(io::IO, inds::AbstractIndices)
    limit = get(io, :limit, false) ? Int64(10) : typemax(Int64)
    comma = false
    print(io, "{")
    for i in inds
        if comma
            print(io, ", ")
        end
        if limit == 0
            print(io, "…")
            break
        end
        show(io, i)
        comma = true
        limit -= 1
    end
    print(io, "}")
end

function Base.show(io::IO, d::AbstractDictionary)
    limit = get(io, :limit, false) ? Int64(10) : typemax(Int64)
    comma = false
    print(io, "{")
    for (i, v) in pairs(d)
        if comma
            print(io, ", ")
        end
        if limit == 0
            print(io, "…")
            break
        end
        show(io, i)
        print(io, " │ ")
        show(io, v)
        comma = true
        limit -= 1
    end
    print(io, "}")
end

# The "display"-like rendering
function Base.show(io::IO, ::MIME"text/plain", d::AbstractIndices)
    if isempty(d)
        print(io, "0-element $(typeof(d))")
        return
    end

    # Designed to be efficient for very large sets of unknown lengths

    n_lines = max(Int64(3), get(io, :limit, false) ? Int64(displaysize(io)[1] - 4) : typemax(Int64))
    n_cols = max(Int64(2), get(io, :limit, false) ? Int64(displaysize(io)[2] - 1) : typemax(Int64))
    n_lines_top = n_lines ÷ Int64(2)
    n_lines_bottom = n_lines - n_lines_top

    # First we collect strings of all the relevant elements
    top_ind_strs = Vector{String}()
    bottom_ind_strs = Vector{String}()

    top_lines = Int64(1)
    top_full = false
    top_last_index = Base.RefValue{keytype(d)}()
    for i in keys(d)
        push!(top_ind_strs, sprint(show, i, context = io, sizehint = 0))
        top_lines += 1
        if top_lines > n_lines_top
            top_full = true
            top_last_index[] = i
            break
        end
    end

    bottom_lines = Int64(1)
    bottom_full = false
    if top_full
        for i in Iterators.reverse(keys(d))
            if bottom_full
                if isequal(i, top_last_index[])
                    bottom_full = false # overide this, we don't need the ⋮
                else
                    bottom_ind_strs[end] = "⋮"
                end
                break
            end

            if isequal(i, top_last_index[])
                # Already rendered, we are finished
                break
            end

            push!(bottom_ind_strs, sprint(show, i, context = io, sizehint = 0))
            bottom_lines += 1
            if bottom_lines > n_lines_bottom
                bottom_full = true
                # We check the next element to see if this one should be a ⋮
            end
        end
        ind_strs = vcat(top_ind_strs, reverse(bottom_ind_strs))
    else
        ind_strs = top_ind_strs
    end

    if Base.IteratorSize(d) === Base.SizeUnknown()
        if bottom_full
            print(io, ">$(length(ind_strs))-element $(typeof(d))")
        else
            print(io, "$(length(ind_strs))-element $(typeof(d))")
        end
    else
        print(io, "$(length(d))-element $(typeof(d))")
    end

    # Now find padding sizes
    max_ind_width = maximum(textwidth, ind_strs)
    if max_ind_width + 1 > n_cols
        shrink_to!(ind_strs, n_cols)
    end

    for ind_str in ind_strs
        print(io, "\n ")
        print(io, ind_str)
    end
end

function Base.show(io::IO, ::MIME"text/plain", d::AbstractDictionary)
    n_inds = length(d)
    print(io, "$n_inds-element $(typeof(d))")
    if n_inds == 0
        return
    end
    n_lines = max(3, get(io, :limit, false) ? Int64(displaysize(io)[1] - 5) : typemax(Int64))
    n_cols = max(8, get(io, :limit, false) ? Int64(displaysize(io)[2] - 4) : typemax(Int64))
    lines = 1

    # First we collect strings of all the relevant elements
    ind_strs = Vector{String}()
    val_strs = Vector{String}()

    lines = 1
    too_many_lines = false
    for i in keys(d)
        push!(ind_strs, sprint(show, i, context = io, sizehint = 0))
        if isassigned(d, i)
            push!(val_strs, sprint(show, d[i], context = io, sizehint = 0))
        else
            push!(val_strs, "#undef")
        end
        lines += 1
        if lines > n_lines && lines < n_inds
            too_many_lines = true
            break
        end
    end

    # Now find padding sizes
    max_ind_width = maximum(textwidth, ind_strs)
    max_val_width = maximum(textwidth, val_strs)
    if max_ind_width + max_val_width > n_cols
        val_width = max_val_width
        ind_width = max_ind_width
        while ind_width + val_width > n_cols
            if ind_width > val_width 
                ind_width -= 1
            else 
                val_width -= 1
            end
        end
        if ind_width != max_ind_width
            shrink_to!(ind_strs, ind_width)
        end
        if val_width != max_val_width
            shrink_to!(val_strs, val_width)
        end
    else
        ind_width = max_ind_width
    end

    for (ind_str, val_str) in zip(ind_strs, val_strs)
        print(io, "\n ")
        print(io, " " ^ max(0, ind_width - textwidth(ind_str)))
        print(io, ind_str)
        print(io, " │ ")
        print(io, val_str)
    end
    if too_many_lines
        print(io, "\n")
        print(io, " " ^ ind_width)
        print(io, "⋮ │ ⋮")
    end
end

function shrink_to!(strs, width)
    for i in keys(strs)
        str = strs[i]
        if textwidth(str) > width
            new_str = ""
            w = 0
            for c in str
                new_w = textwidth(c)
                if new_w + w < width
                    new_str = new_str * c
                    w += new_w
                else
                    new_str = new_str * "…"
                    break
                end
            end
            strs[i] = new_str
        end
    end
end

# TODO fix `repr`
