using StochasticPrograms
using CPLEX

Crops = [:wheat , :corn , :beets]

Crops = Crops
Cost = Dict(:wheat => 150 , :corn => 230 , :beets =>260)
Budget = 500

Required = Dict(:wheat => 200 , :corn => 240 , :beets =>0)
PurchasePrice = Dict(:wheat => 238 , :corn => 210)
SellPrice = Dict(:wheat => 170 , :corn => 150 , :beets => 36, :extrabeets => 10)

Crops = [:wheat, :corn, :beets]
@stochastic_model farmer_model begin
    @stage 1 begin
        @parameters begin
            Crops = Crops
            Cost = Dict(:wheat=>150, :corn=>230, :beets=>260)
            Budget = 500
        end
        @decision(farmer_model, x[c in Crops] >= 0)
        @objective(farmer_model, Min, sum(Cost[c]*x[c] for c in Crops))
        @constraint(farmer_model, sum(x[c] for c in Crops) <= Budget)
    end
    @stage 2 begin
        @parameters begin
            Crops = Crops
            Required = Dict(:wheat=>200, :corn=>240, :beets=>0)
            PurchasePrice = Dict(:wheat=>238, :corn=>210)
            SellPrice = Dict(:wheat=>170, :corn=>150, :beets=>36, :extra_beets=>10)
        end
        @uncertain ξ[c in Crops]
        @recourse(farmer_model, y[p in setdiff(Crops, [:beets])] >= 0)
        @recourse(farmer_model, w[s in Crops ∪ [:extra_beets]] >= 0)
        @objective(farmer_model, Min, sum(PurchasePrice[p] * y[p] for p in setdiff(Crops, [:beets]))
                   - sum(SellPrice[s] * w[s] for s in Crops ∪ [:extra_beets]))
        @constraint(farmer_model, minimum_requirement[p in setdiff(Crops, [:beets])],
            ξ[p] * x[p] + y[p] - w[p] >= Required[p])
        @constraint(farmer_model, minimum_requirement_beets,
            ξ[:beets] * x[:beets] - w[:beets] - w[:extra_beets] >= Required[:beets])
        @constraint(farmer_model, beets_quota, w[:beets] <= 6000)
    end
end

ξ1 = @scenario ξ[c in Crops] = [3.0, 3.6, 24.0] probability = 1/3
ξ2 = @scenario ξ[c in Crops] = [2.5, 3.0, 20.0] probability = 1/3
ξ3 = @scenario ξ[c in Crops] = [2.0, 2.4, 16.0] probability = 1/3

sp = instantiate(farmer_model, [ξ1, ξ2, ξ3], optimizer = CPLEX.Optimizer)

print(sp)

optimize!(sp)

x = optimal_decision(sp)

x = sp[1, :x]

println("wheat : $(value(x[:wheat]))")

println("corn : $(value(x[:beets]))")

println("beets : $(value(x[:beets]))")

y = sp[2, :y]

w = sp[2, :w]

println("purchased wheat : ", value(y[:wheat],1) )
println("purchased wheat : ", value(y[:wheat],2) )
println("purchased wheat : ", value(y[:wheat],3) )

