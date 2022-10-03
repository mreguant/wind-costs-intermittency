# Code and data repository for "Quantifying the Impact of Wind Power in the Spanish Electricity Market" #

Authors: Claire Petersen and Mar Reguant

## Description
This repository replicates the results for the paper "Quantifying the Impact of Wind Power in the Spanish Electricity Market." It has been run mostly using Stata although R and Python are used for pre-data processing. 

Note: Due to the large size of the raw files used in this project, the raw data are not provided. Raw data is available upon request.

## code_stata
The primary analysis of this paper is generated using master_run_code.do. This organizational code runs a series of other do files, described below.
 - create_intermittency.do
     - inputs: data_systemcosts.dta, data_renewable_production.dta, data_actual_demand.dta, data_forecast_demand.dta, data_forecast_wind_aggregate.dta, data_marketprices_wide.dta, data_weather_hourly.dta, nat_gas_prices.dta, EU_ETS_prices.dta, emissions_data.dta
     - output: data_costs_intermittency.dta
 - table_summary_statistics.do
     - inputs: data_costs_intermittency.dta, data_deviationsprices.dta
     - output: table_summary_statistics.tex
 - pre_post_graphs.do
     - inputs: data_costs_intermittency.dta
     - outputs: price_2014_break.pdf, wind_curtailment_2014_break.pdf
 - graph_distribution_intermittency.do
     - inputs: data_systemcosts.dta, data_renewable_production.dta, data_actual_demand.dta, data_forecast.dta, data_forecast_wind_aggregate.dta, data_costs_intermittency.dta
     - outputs: graph_distribution_volatility.pdf, graph_distribution_uncertainty.pdf
 - analysis_tables.do
     - inputs: data_costs_intermittency.dta
     - outputs: table_fe, table_controls3, table_controls3_daily, table_wind
  - analysis_graphs.do
     - inputs: data_costs_intermittency.dta, results_spline_regressions.dta, results_spline_regressions_prices.dta, results_VU_regressions.dta, results_spline_welfare_regressions_NEW.dta, results_LINEAR_welfare_regressions_NEW.dta, results_yr_regressions.dta
     - outputs: Spline_FeHr2_C5_Costs_Margins_Averages.pdf, Spline_FeHr2_C5_Price2_Margins_Averages.pdf, Spline_FeHr2_C5_Price3_Margins_Averages.pdf, Spline_FeHr2_C5_Emissions_Margins_Averages.pdf, Spline_FeHr2_C5_TCost_Averages_Comparison.pdf, Unc1_FeSh_C8_Costs_Margins_Averages.pdf, Vol1_FeSh_C8_Costs_Margins_Averages.pdf, Welfare_New1.pdf, Welfare_New2.pdf, Welfare_New3_SCC100_DIFF.pdf, Annual_Graph.pdf
- analysis_regressions.do
     - inputs: data_costs_intermittency.dta
     - outputs: results_spline_regressions.dta, results_yr_regressions.dta, results_spline_welfare_regressions_NEW.dta, results_linear_welfare_regressions_NEW.dta
- analysis_regressions_VU.do
     - inputs: data_costs_intermittency.dta
     - outputs: results_VU_regressions.dta
 

## Sources:
- Red Electrica de Espana (REE), and the the Iberian electricity Market Operator (OMIE):
     - Electricity demand (liquicomm)
     - Electricity generation by source (liquicomm)
     - Market clear prices (liquicomm)
     - CO2 emissions
     - Demand forecast (hemeroteca_DD)
     - Wind forecast (hemeroteca_DD)
- Bloomberg Markets:
     - Natural gas prices
- Wunderground:
     - Temperature, humididy, pressure, wind speed (prior to 2017)
- Tutiempo:
     - Temperature, humididy, pressure, wind speed (2017 - 2018)
- Sandbag Smarter Carbon Policy - Carbon Viewer Page
     - EU-ETS prices
     
