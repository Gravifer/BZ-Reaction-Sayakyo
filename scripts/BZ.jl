#!/usr/bin/env julia --project=@.
using DrWatson
@quickactivate "BZ_Bridge"
using StrideArraysCore
using LinearAlgebra, Random
using StaticArrays, OffsetArrays
# using CUDA
using Images, ImageFiltering
using GLMakie, ProgressBars

println("+++++ Packages loaded +++++")

# Width, height of the image.
nx, ny = 400, 300 #2048, 1536
# Reaction parameters.
const alpha, beta, gamma = 1.2, 1.0, 1.0

s = zeros(Float32, nx, ny, 3)
const m = centered(fill(1/9, (3, 3)))

function update!(p::Int, arr::AbstractArray{T, 4}, s::AbstractArray{T, 3}) where {T <: AbstractFloat}
    """Update arr[p] to arr[q] by evolving in time."""

    q = p % 2 + 1
    for k in 1:3
        @inbounds imfilter!(view(s, :, :, k), view(arr, :, :, k, p), m, "circular")
    end
    @views begin
        @inbounds begin
            @. arr[:, :, 1, q] = s[:, :, 1] + s[:, :, 1]*(alpha * s[:, :, 2] - gamma * s[:, :, 3])
            @. arr[:, :, 2, q] = s[:, :, 2] + s[:, :, 2]*(beta  * s[:, :, 3] - alpha * s[:, :, 1])
            @. arr[:, :, 3, q] = s[:, :, 3] + s[:, :, 3]*(gamma * s[:, :, 1] - beta  * s[:, :, 2])
        end
    end
    # foreach(x -> clamp!.(x, 0.0, 1.0), eachslice(arr[q, :, :, :], dims=1))
    clamp!(view(arr, :, :, :, q), 0.0f0, 1.0f0)
    # return arr
    return nothing
end

# Initialize the array with random amounts of A, B and C.
arr = rand(Float32, nx, ny, 3, 2)

# Set up the plot
fig, ax, plt = image(view(arr, :, :, 1, 1), colormap = [:red, :blue])

record(fig, plotsdir("bz.mp4"), ProgressBar(1:200)) do i
    update!((i - 1) % 2 + 1, arr, s)
    image!(ax, view(arr,:, :, 1, ((i - 1) % 2) + 1), colormap = [:red, :blue])
end

run(`code $(plotsdir("bz.mp4"))`)

# function animate_bz!(plt, arr, frames=200)
#     anim = @animate for i in ProgressBar(1:frames)
#         update!((i - 1) % 2 + 1, arr, s)
#         heatmap!(plt, view(arr,:, :, 1, ((i - 1) % 2) + 1), color=:winter, plot_title = "Step $(i)")
#     end
#     return anim
# end

# previous_GKSwstype = get(ENV, "GKSwstype", "")
# ENV["GKSwstype"] = "100"
# anim = animate_bz!(plt, arr, 200)
# gif(anim, plotsdir("bz.gif"), fps=5)
# ENV["GKSwstype"] = previous_GKSwstype 
