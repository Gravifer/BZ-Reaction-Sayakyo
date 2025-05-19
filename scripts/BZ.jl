#!/usr/bin/env julia --project=@.

# using Revise
using DrWatson
@quickactivate "BZ_Bridge"
# @time begin
    using LinearAlgebra, Random
    using StaticArrays, OffsetArrays
    # using CUDA
    using Images, ImageIO, Colors
    using ImageFiltering
    using GLMakie, ProgressBars
    # GLMakie.activate!(renderloop = false)
# end; println("+++++ Packages loaded +++++")

const magica_colors = Dict(
    :sayaka => colorant"#1c2e78",
    :kyoko  => colorant"#841b1a",
)

# Width, height of the image.
const nx::Int, ny::Int = 320, 240; # 2048, 1536
# Reaction parameters.
const alpha::Float32, beta::Float32, gamma::Float32 = 1.2, 1.2, 1.0
const vel::Float32 = 1
outfile = "bz_$(nx)-$(ny)_$(alpha)-$(beta)-$(gamma).vel$(vel).mp4"

s = zeros(Float32, nx, ny, 3)
const m = centered(fill(Float32(1/9), (3, 3)))

function update!(p::Int, arr::AbstractArray{T, 4}, s::AbstractArray{T, 3}; diffuseonly::Bool = false, pertfunc::Union{Nothing, Function} = nothing) where {T <: AbstractFloat}
    """Update arr[p] to arr[q] by evolving in time."""

    q::Int = p % 2 + 1
    @inbounds begin
        for k in 1:3
            for i in 1:nx, j in 1:ny
                im1::Int = mod1(i - 1, nx); ip1::Int = mod1(i + 1, nx)
                jm1::Int = mod1(j - 1, ny); jp1::Int = mod1(j + 1, ny)
                s[i, j, k] = (
                    arr[im1, jm1, k, p] + arr[i, jm1, k, p] + arr[ip1, jm1, k, p] +
                    arr[im1, j,   k, p] + arr[i, j,   k, p] + arr[ip1, j,   k, p] +
                    arr[im1, jp1, k, p] + arr[i, jp1, k, p] + arr[ip1, jp1, k, p]
                    # + (if pertfunc !== nothing; pertfunc(); else 0.0f0; end) # .01 * (rand(Float32) - .5)
                ) * (1/9)
            end
            # imfilter!(view(s, :, :, k), view(arr, :, :, k, p), m, "circular") # view reduces allocation
        end
        @views if diffuseonly; 
            @. arr[:, :, 1, q] = s[:, :, 1]
            @. arr[:, :, 2, q] = s[:, :, 2]
            @. arr[:, :, 3, q] = s[:, :, 3]
        else
            @. arr[:, :, 1, q] = s[:, :, 1] + s[:, :, 1]*(alpha * s[:, :, 2] - gamma * s[:, :, 3]) *vel
            @. arr[:, :, 2, q] = s[:, :, 2] + s[:, :, 2]*(beta  * s[:, :, 3] - alpha * s[:, :, 1]) *vel
            @. arr[:, :, 3, q] = s[:, :, 3] + s[:, :, 3]*(gamma * s[:, :, 1] - beta  * s[:, :, 2]) *vel
        end
    end
    clamp!(view(arr, :, :, :, q), 0.0f0, 1.0f0)
    # return arr
    return nothing
end

# Initialize the array with random amounts of A, B and C.
# arr = rand(Float32, nx, ny, 3, 2)
arr = zeros(Float32, nx, ny, 3, 2) # Initialize the array with prescribed A and B.
arr[:, :, 1, 1] = arr[:, :, 1, 2] = Float32.(load(plotsdir("start.png"))')
arr[:, :, 2, 1] = arr[:, :, 2, 2] = (gamma / beta) .* Float32.(load(plotsdir("start.png"))') .+ .5 * rand(Float32, nx, ny)
arr[:, :, 3, 1] = arr[:, :, 3, 2] = (gamma / alpha) .* Float32.(load(plotsdir("start.png"))') # @. .0 * rand(Float32, nx, ny) + .0 * Float32.(1 - load(plotsdir("start.png"))')

# Set up the plot
imgdata = Observable(view(arr, :, :, 1, 1))

# fig, ax, plt = image(imgdata, colormap = [magica_colors[:kyoko], magica_colors[:sayaka]], colorrange = (0.0f0, 1.0f0))
fig = Figure()

ax = GLMakie.Axis(fig[1, 1]; 
    # width = 1920, height = 1080,
    backgroundcolor = :transparent,
    leftspinevisible = false,
    rightspinevisible = false,
    topspinevisible = false,
    bottomspinevisible = false
)
hidespines!(ax); hidedecorations!(ax)
resize_to_layout!(fig)

image!(ax, imgdata, 
    colorrange = (0.0f0, 1.0f0), 
    colormap = [magica_colors[:kyoko], magica_colors[:sayaka]]
)


record(fig, plotsdir(outfile); framerate=30, visible=false, compression = 5) do io
    pbar = ProgressBar(total=1800)
    for i in 1:30
        recordframe!(io); update(pbar)
    end
    for i in 31:60
        update!((i - 1) % 2 + 1, arr, s; diffuseonly = true)
        imgdata[] = view(arr, :, :, 1, (i - 1) % 2 + 1) # @time image!(ax, view(arr,:, :, 1, ((i - 1) % 2) + 1), colormap = [:red, :blue])
        recordframe!(io); update(pbar)
    end
    for i in 61:600
        if i % 100 == 0
            arr .+= .01f0 .* (rand(Float32, nx, ny, 3, 2) .- 0.5f0)
        end
        update!((i - 1) % 2 + 1, arr, s)
        imgdata[] = view(arr, :, :, 1, (i - 1) % 2 + 1) # @time image!(ax, view(arr,:, :, 1, ((i - 1) % 2) + 1), colormap = [:red, :blue])
        recordframe!(io); update(pbar)
    end
    for i in 601:1000
        if i % 50 == 0
            arr .+= .1f0 .* (rand(Float32, nx, ny, 3, 2) .- 0.5f0)
        end
        update!((i - 1) % 2 + 1, arr, s)
        imgdata[] = view(arr, :, :, 1, (i - 1) % 2 + 1) # @time image!(ax, view(arr,:, :, 1, ((i - 1) % 2) + 1), colormap = [:red, :blue])
        recordframe!(io); update(pbar)
    end
    for i in 1001:1500
        if i % 10 == 0
            arr .+= .5f0 .* (rand(Float32, nx, ny, 3, 2) .- 0.5f0)
        end
        update!((i - 1) % 2 + 1, arr, s)
        imgdata[] = view(arr, :, :, 1, (i - 1) % 2 + 1) # @time image!(ax, view(arr,:, :, 1, ((i - 1) % 2) + 1), colormap = [:red, :blue])
        recordframe!(io); update(pbar)
    end
    for i in 1501:1700
        if i % 5 == 0
            arr .+= 0.8f0 .* (rand(Float32, nx, ny, 3, 2) .- 0.5f0)
        end
        update!((i - 1) % 2 + 1, arr, s)
        imgdata[] = view(arr, :, :, 1, (i - 1) % 2 + 1) # @time image!(ax, view(arr,:, :, 1, ((i - 1) % 2) + 1), colormap = [:red, :blue])
        recordframe!(io); update(pbar)
    end
    for i in 1701:1770
        if i % 2 == 0
            arr .+= 1.2f0 .* (rand(Float32, nx, ny, 3, 2) .- 0.5f0)
        end
        update!((i - 1) % 2 + 1, arr, s)
        imgdata[] = view(arr, :, :, 1, (i - 1) % 2 + 1) # @time image!(ax, view(arr,:, :, 1, ((i - 1) % 2) + 1), colormap = [:red, :blue])
        recordframe!(io); update(pbar)
    end
    for i in 1771:1800
        if true
            arr .+= 1.8f0 .* (rand(Float32, nx, ny, 3, 2) .- 0.5f0)
        end
        update!((i - 1) % 2 + 1, arr, s)
        imgdata[] = view(arr, :, :, 1, (i - 1) % 2 + 1) # @time image!(ax, view(arr,:, :, 1, ((i - 1) % 2) + 1), colormap = [:red, :blue])
        recordframe!(io); update(pbar)
    end
end

run(`cmd /C code $(plotsdir(outfile))`)
