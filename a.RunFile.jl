#RUN FILE

# Calls the Packages used for the optimization problem
using JuMP
using Printf
using Gurobi
#using CPLEX
using MathOptInterface
using JLD
using TimerOutputs
using DataFrames
using XLSX
using Parameters
using Dates

using CSV

# Calls the other Julia files
include("Structures.jl")
include("SetInputParameters.jl")
include("solveOptimizationAlgorithm.jl")        #solveOptimizationAlgorithm_3cuts
include("ProblemFormulationInequalities.jl")      #ProblemFormulationCutsTaylor_3
include("Saving in xlsx.jl")

#########  5 YEARS WITHOUR REVAMPING
include("Rolling_Planning.jl")
include("Rolling_problem.jl")

date = string(today())

# PREPARE INPUT DATA
to = TimerOutput()

@timeit to "Set input data" begin

  #Set run case - indirizzi delle cartelle di input ed output
  case = set_runCase()

  @unpack (DataPath,InputPath,ResultPath,CaseName) = case;

  # Set run mode (how and what to run) and Input parameters
  runMode = read_runMode_file()
  InputParameters = set_parameters(runMode, case)
  @unpack (NYears, NMonths, NHoursStep, NStages, Big, conv, disc, Hours_rolling, Hours_saved)= InputParameters;    #NSteps, NHoursStage

  # Upload battery's characteristics
  Battery = set_battery_system(runMode, case)
  @unpack (min_SOC, max_SOC, Eff_charge, Eff_discharge, min_P, max_P, max_SOH, min_SOH, Nfull, cost, fix) = Battery; 

  # Set solver parameters (Gurobi etc)
  SolverParameters = set_solverParameters()

  # Read power prices from a file [€/MWh]
  #Steps_stages = [0 1132 2259 3397 4465 5650 6723 7806 8843 9953 10946 12124 13171 14283 15273 16385 17375 18460 19470 20496 21505] #every semester
  Steps_stages = [0 2259 4465 6723 8843 10946] # yearly revamping over 5 years
  #Steps_stop = [128 127 120 111 127 115 115 123 120] # 3 weeks downtime
  Steps_stop = [120 127 115 120] # 3 weeks downtime
  NSteps = Steps_stages[NStages+1]

  Battery_price_purchase = read_csv("Mid-cost projections 2026-2036_5_years.csv",case.DataPath)
  Battery_price_sale = set_price(Battery_price_purchase,cost);
  
  Power_prices = read_csv("Filtered_2026_2036.csv", case.DataPath);    

  # Where and how to save the results
  FinalResPath= set_run_name(case, ResultPath, NSteps)

end

#=save input data
@timeit to "Save input" begin
    save(joinpath(FinalResPath,"CaseDetails.jld"), "case" ,case)
    save(joinpath(FinalResPath,"SolverParameters.jld"), "SolverParameters" ,SolverParameters)
    save(joinpath(FinalResPath,"InputParameters.jld"), "InputParameters" ,InputParameters)
    save(joinpath(FinalResPath,"BatteryCharacteristics.jld"), "BatteryCharacteristics" ,Battery)
    save(joinpath(FinalResPath,"PowerPrices.jld"),"PowerPrices",Power_prices)
end=#

@timeit to "Solve optimization problem" begin
  ResultsOpt = solveOptimizationProblem(InputParameters,SolverParameters,Battery);
  save(joinpath(FinalResPath, "optimization_results.jld"), "optimization_results", ResultsOpt)
end

# SAVE DATA IN EXCEL FILES
if runMode.excel_savings
  cartella = "C:\\GitHub_Asja\\Ocra_2.0_IREP\\Results_13_gennaio"
  cd(cartella)
  Saving = data_saving(InputParameters,ResultsOpt)
else
  println("Solved without saving results in xlsx format.")
end



#= ROLLING-PLANNING METHODOLOGY FOR CAPACITY DEGRADATION -  caso 2
if runMode.endlife_rolling
  P1 = read_csv("prices_2019_8760.csv", case.DataPath);
  P2 = read_csv("prices_2020_8760.csv", case.DataPath);
  P3 = read_csv("prices_2021_8760.csv", case.DataPath);
  P4 = read_csv("prices_2022_8760.csv", case.DataPath);
  P5 = read_csv("prices_2023_8760.csv", case.DataPath);

  vec_prices = vcat(P1,P2,P3,P4,P5,P1,P2,P3,P4,P5);

  ResultsEnd = solveRollingPlanning(InputParameters, Battery, ResultsOpt, vec_prices)
  Saving2 = data_saving_rolling(InputParameters,ResultsEnd)
end

if runMode.rolling_newDeg
  p1 = read_csv("prices_2019_8760.csv", case.DataPath);
  p2 = read_csv("prices_2020_8760.csv", case.DataPath);
  p3 = read_csv("prices_2021_8760.csv", case.DataPath);
  p4 = read_csv("prices_2022_8760.csv", case.DataPath);
  p5 = read_csv("prices_2023_8760.csv", case.DataPath);

  prices = vcat(p1,p2,p3,p4,p5,p1,p2,p3,p4,p5);

  NewDeg = solveNewDegradation(InputParameters, Battery, ResultsOpt, prices)
  Saving3 = saving_new_deg(InputParameters,ResultsEnd)
end

# caso 1 - no rolling su 5 anni senza revamping 
if runMode.endlife
  Pa = read_csv("prices_2019_8760.csv", case.DataPath);
  Pb = read_csv("prices_2020_8760.csv", case.DataPath);
  Pc = read_csv("prices_2021_8760.csv", case.DataPath);
  Pd = read_csv("prices_2022_8760.csv", case.DataPath);
  Pe = read_csv("prices_2023_8760.csv", case.DataPath);

  vec_p = vcat(Pa,Pb,Pc,Pd,Pe,Pa,Pb,Pc,Pd,Pe);
  Tot_steps = length(vec_p)
  RE = solveCase1(InputParameters, Battery, ResultsOpt, vec_p, Tot_steps)
  Saving1= data_endlife(InputParameters,RE)
end

print(to)
=#



