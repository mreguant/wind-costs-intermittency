/*******************************************************************************
Create summary statistic table, output in Latex format
Input: data_actual_demand.dta, data_renewable_production.dta, data_wind_farms.dta
	   data_systemcosts.dta, data_deviationsprices.dta
Output: Latex Table of Summary Statistics
*******************************************************************************/
*Last updated: October 26, 2017

/*Process:
-Loop runs through each data file, extracts summary statistics, creates matrix row of summary stats
-"Stack" each matrix row on top of each other
-Relabel columns and rows
-Export to Latex */

clear all
set type double
set more off
program drop _all

*Creates each row of our summary statistics table

use "$dirpath/data/output/data_costs_intermittency.dta", clear 
*summarize wind_dev price_da, d

gen cost_wind = (cost_dw + cost_up)/(wind+wind_up+wind_dw)

local costint actual_demand wind_forecast photov_final price0 totalcost congestion_cost insurance_cost adjustment_cost cost_wind emis_tCO2
foreach var of local costint {
	summarize `var', d
	scalar mean = round(r(mean), .01)
	scalar sd = round(r(sd), .01)
	scalar p25 = round(r(p25), .01)
	scalar p50 = round(r(p50), .01)
	scalar p75 = round(r(p75), .01)
	*mat `var' = r(mean), r(sd), r(p25), r(p50), r(p75)
	mat `var' = mean, sd, p25, p50, p75
}

summ 

mat Summary = actual_demand\wind_forecast\photov_final\price0\totalcost\congestion_cost\adjustment_cost\insurance_cost\cost_wind\emis_tCO2
matrix rownames Summary = "Actual Demand (GWh)" "Wind Forecast (GWh)" "Solar production (GWh)" ///
"Price DA (EUR/MWh)" "Operational Costs (EUR/MWh)" "\ - Restrictions Costs (EUR/MWh)" ///
"\ - Insurance Costs (Euro/MWh)" "\ - Deviations Costs (EUR/MWh)" "Costs to Wind (EUR/MWh of wind)" "CO2 Emissions (tCO2)"
matrix colnames Summary = Mean SD P25 P50 P75
esttab matrix(Summary) using "$dirpath/tables/table_summary_statistics.tex", t(3) replace

