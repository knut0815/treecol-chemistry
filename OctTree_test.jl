push!(LOAD_PATH, pwd())
#import Pkg; Pkg.add("HDF5"); Pkg.add("StaticArrays"); Pkg.add("PyPlot");
#Pkg.add("DifferentialEquations"); Pkg.add("Parameters"); Pkg.add("Sundials");
using OctTree

using HDF5
using StaticArrays
using Statistics
#using PyPlot
using LinearAlgebra
using .Threads
#using Serialization
using Random

import Plots #if needed, it has to be imported before PyPlot otherwise it'll crash
using PyPlot


const BOXSIZE_X = BOXSIZE_Y = BOXSIZE_Z = 1.0

const ANGLE = 0.7
const ShieldingLength = 0.1

N=3
T=Float64


function plot_quadtree(node::Node{N,T}, ix, iy) where {N,T}
    #println("center=", node.center)
    #println("length=", node.length)
    if N<2 println("N must be >= 2")
        return
    end
    xmin = node.center[ix] - 0.5*node.length[ix]
    xmax = node.center[ix] + 0.5*node.length[ix]
    ymin = node.center[iy] - 0.5*node.length[iy]
    ymax = node.center[iy] + 0.5*node.length[iy]
    color="grey"
    plot([xmin,xmin],[ymin,ymax], c=color)
    plot([xmin,xmax],[ymin,ymin], c=color)
    plot([xmax,xmax],[ymin,ymax], c=color)
    plot([xmin,xmax],[ymax,ymax], c=color)
    if node.child != nothing
        for i in 1:2^N
            plot_quadtree(node.child[i], ix, iy)
        end
    end
end

function plot_circles_scatter_ngbs(X::Vector{SVector{N,T}}, hsml::Vector{T}, boxsizes::SVector{N,T}) where {N,T}
    for i in eachindex(X)
        mycircle(hsml[i], X[i][1], X[i][2], 0.5*boxsizes[1], 0.5*boxsizes[2], boxsizes[1], boxsizes[2], "green")
    end
end

function mycircle(r, xc, yc, x0, y0, boxsizeX, boxsizeY, color)
    #xc=1.5;yc=2.5;r=0.5
    x = collect(-r : 0.0001*r : r)
    y = sqrt.( r.^2 .- x.^2 )
    xx = x.+xc
    yy = y.+yc
    #x0 = 0.5*boxHalf_X # coordinates for the center of box
    #y0 = 0.5*boxHalf_Y # coordinates for the center of box
    xx[xx .> x0+boxsizeX*0.5] .-= boxsizeX
    xx[xx .< x0-boxsizeX*0.5] .+= boxsizeX
    yy[yy .> y0+boxsizeY*0.5] .-= boxsizeY
    yy[yy .< y0-boxsizeY*0.5] .+= boxsizeY
    scatter(xx,yy,marker=".",c=color,s=0.03)
    xx = x.+xc
    yy = -y.+yc
    xx[xx .> x0+boxsizeX*0.5] .-= boxsizeX
    xx[xx .< x0-boxsizeX*0.5] .+= boxsizeX
    yy[yy .> y0+boxsizeY*0.5] .-= boxsizeY
    yy[yy .< y0-boxsizeY*0.5] .+= boxsizeY
    scatter(xx,yy,marker=".",c=color,s=0.03)
end

function plot_treewalk(ga::TreeGather{T},ix,iy) where {T}
    for i in eachindex(ga.nodecenters)
        if ga.nodelengths[i][1] == 0
            #plot(ga.nodecenters[i][ix], ga.nodecenters[i][iy], ".", c="red")
        else
            xmin = ga.nodecenters[i][ix] - 0.5*ga.nodelengths[i][ix]
            xmax = ga.nodecenters[i][ix] + 0.5*ga.nodelengths[i][ix]
            ymin = ga.nodecenters[i][iy] - 0.5*ga.nodelengths[i][iy]
            ymax = ga.nodecenters[i][iy] + 0.5*ga.nodelengths[i][iy]
            color="green"
            plot([xmin,xmin],[ymin,ymax], c=color)
            plot([xmin,xmax],[ymin,ymin], c=color)
            plot([xmax,xmax],[ymin,ymax], c=color)
            plot([xmin,xmax],[ymax,ymax], c=color)
        end
    end
end




function test(X::Vector{SVector{N,T}}) where {N,T}
    if N==3
        boxsizes = SVector{N,T}(BOXSIZE_X, BOXSIZE_Y, BOXSIZE_Z)
    elseif N==2
        boxsizes = SVector{N,T}(BOXSIZE_X, BOXSIZE_Y)
    elseif N==1
        boxsizes = SVector{N,T}(BOXSIZE_X)
    end

    hsml0 = 0.1*BOXSIZE_X
    Npart = length(X)
    hsml = ones(T,Npart) .* hsml0
    hsml .*= (1.5 .- rand(Npart))
    #mass = [1,0.1,0.3]
    mass = ones(Npart)
    mass_H2 = ones(Npart)
    mass_CO = ones(Npart)
    @time tree = buildtree(X, hsml, mass, mass_H2, mass_CO, boxsizes);
    #idx_ngbs = get_scatter_ngb_tree(p, tree, boxsizes)
    #idx_ngbs = get_gather_ngb_tree(p, hsml0, tree, boxsizes)
    #@show length(idx_ngbs)

    ga_out = Vector{TreeGather{Float64}}(undef,Npart)
    @time for i in 1:Npart
        ga = TreeGather{T}()
        treewalk(ga, X[i], tree, ANGLE, ShieldingLength, boxsizes)
        #treewalk(ga,X[i], tree, ANGLE, boxsizes)
        #column_all = (ga.column_all);
        ga_out[i] = ga
    end

    #ix=1
    #iy=2
    #xngb = getindex.(X[idx_ngbs], ix)
    #yngb = getindex.(X[idx_ngbs], iy)

    #fig = figure("tree",figsize=(8,8))
    #plot_quadtree(tree, ix, iy)  #costly!!!
    #scatter(getindex.(X,ix), getindex.(X,iy), c="blue", marker="o", s=3)
    #scatter( xngb, yngb , marker="o", color="red", s=10)
    #@show xngb, yngb

    #mycircle(hsml0, p[ix], p[iy], 0.5*boxsizes[ix], 0.5*boxsizes[iy], boxsizes[ix], boxsizes[iy], "red")
    #plot_circles_scatter_ngbs(X[idx_ngbs], hsml[idx_ngbs], boxsizes)
    #title("neighbor finder with quadtree")
    #xlabel("x")
    #ylabel("y")
    return tree, ga_out
end

#p = SVector(0.0, 0.0, 0.0) .+ 0.5
#radius = 0.2
#tree,x = test(radius, p, 100);

using Healpix

X = [@SVector rand(N) for _ in 1:10000]
#push!(X,SVector(0.5,0.5,0.5).*BOXSIZE_X) #add a particle at the box center

tree, ga_out = test(X);

println("c.o.m. of the top node = ", sum(X)/length(X))

#=
const fac_col = 8.8674721e23
m = Map{Float64, RingOrder}(NSIDE);
#m.pixels[:] = log10.(ga_out[end].column_all .+ 1e-2*minimum(ga.column_all[ga.column_all.!=0.0]));
m.pixels[:] = log10.(ga_out[end].column_all .* fac_col) ;
#Plots.plot(m, clim=(20.5,24))
Plots.plot(m)
=#