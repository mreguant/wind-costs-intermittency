********************************************************************************
* Create variables at the day-hour level reflecting changes accross hours
********************************************************************************

clear
clear matrix
set more off
*set matsize 2000

* READ DATA IN -----------------------------------------------------------------
cd "$dirpath/data/input/"

* Some totalcosts were missing
use "data_systemcosts.dta", clear

bys year month day hour (totaldemand): gen obs = _N
bys year month day hour (totaldemand): gen obss = _n
drop if obs==2 & obss==1
drop obs*

sort year month day hour
merge 1:1 year month day hour using "data_renewable_production.dta", nogen keep(1 3)
keep year month day hour wind* photo* rest* ///
	 reserve secondary costdeviations netdeviations po14 totalcost
drop if hour==25
merge m:1 year month day hour using "data_actual_demand.dta", nogen keep(1 3)

* Demand forecast
merge 1:m year month day hour using "data_forecast_demand.dta", nogen keep(1 3)
g timeofforecast =  timeToForecast -  hour
gen  closest =  abs(timeofforecast-14)
bys year month day hour: egen min_closest = min(closest)
bys year month day hour: gen equal = (closest== min_closest)
gen demand_forecast = forecast_demand if equal==1
drop timeToForecast timeofforecast-equal
collapse (mean) restrictionsDA-demand_forecast, by(year month day hour)

* Costs of intermittency to study

g congestion_cost = restrictionsDA + restrictionsRT
g adjustment_cost = netdeviations + costdeviations
g insurance_cost  = reserve + secondary

* Define dataset as time series

egen time = group(year month day hour)
tsset time

* GWh
foreach x in wind_final wind wind_dev photov photov_final photov_dev actual_demand demand_forecast forecast_demand errorforecast_d {
replace `x' = `x'/1000
} 

** Change in Final Wind across Hours 
sort time
forvalues h = 1(1)24 {
	gen wind_change`h' = wind_final - L`h'.wind_final
}
reshape long wind_change, i(time year month day hour) j(timeLag)

gen wind_change_abs = abs(wind_change) 
foreach i in 1 2 6 12 24 {
	bysort year month day hour: egen vol`i'    = sd(wind_change) if timeLag<=`i'
	bysort year month day hour: egen volabs`i' = mean(wind_change_abs) if timeLag<=`i'
}
collapse (mean) restrictionsDA-volabs24 , by(year month day hour)

****** Merge new variables with forecast *******
merge 1:m year month day hour using "data_forecast_wind_aggregate.dta", nogen keep(1 3)
drop if hour==25
replace timeToForecast=0 if timeToForecast<0
replace forecast = forecast/1000
replace errorforecast = errorforecast/1000

* Forecast and Wind Produced

gen wind_change_forecast = forecast - wind_final
gen wind_change_forecast_abs = abs(wind_change_forecast)

foreach i in 6 12 24 36 {
	bysort year month day hour: egen unc`i'    = sd(wind_change_forecast) if timeToForecast<=`i'
	bysort year month day hour: egen uncabs`i' = mean(wind_change_forecast_abs) if timeToForecast<=`i'
}

* Generate wind forecast

g timeofforecast =  timeToForecast -  hour
gen  closest =  abs(timeofforecast-14)
bys year month day hour: egen min_closest = min(closest)
bys year month day hour: gen equal = (closest== min_closest)
gen wind_forecast = forecast if equal==1
drop timeToForecast forecast errorforecast timeofforecast-equal

collapse (mean) restrictionsDA-wind_forecast , by(year month day hour)

* Construct week and add it to the data

g eventdate = mdy(month, day, year)
g dayofweek = dow(eventdate)
drop eventdate

* Create useful wind measures

g windrel = (wind_forecast/actual_demand)
xtile wind_10  = wind_forecast, nq(10)
xtile wind_5  = wind_forecast, nq(5)
xtile windrel_10  = windrel, nq(10)
xtile windrel_5  = windrel, nq(5)

* Merge with data for prices, forecast, quantities and weather

sort year month day hour
merge 1:1 year month day hour using "data_marketprices_wide.dta", nogen keep(1 3)
drop price1-price7


* Merge with final prices

sort year month day hour
merge 1:1 year month day hour using "data_finalprices.dta", nogen keep(1 3)


* Merge with natural gas price data
merge m:1 year month day using "nat_gas_prices.dta"
fillmissing ng_spot_p, with(previous)
fillmissing ng_spot_p, with(next)
drop _merge

* Merge with Emissions Data (note, March DST hour 24 rows created)
sort year month day hour
merge year month day hour using "emissions_data.dta"
drop _merge
sort year month day hour


* Merge costs of deviations to wind farms

merge 1:1 year month day hour using "$dirpath/data/input/data_deviations_all.dta", keep(3) nogen keepusing(wind_up wind_dw)
merge 1:1 year month day hour using "$dirpath/data/input/data_deviationsprices.dta", keep(3) nogen keepusing(price_up price_dw)


replace wind_dw = wind_dw / 1000.0
replace wind_up = wind_up / 1000.0

gen price_wind =  (price0*wind + price_up*wind_up + price_dw*wind_dw)/(wind+wind_up+wind_dw)
gen cost_up     = (price0-price_up)*wind_up
gen cost_dw     = -(price_dw-price0)*wind_dw 
gen ocost_up    = (price0-price_up)
gen ocost_dw    = (price_dw-price0) 


* Add weather controls

merge 1:1  year month day hour using "$dirpath/data/input/data_weather_hourly.dta", keep(1 3) nogen
gen tempMEANsq = tempMEAN*tempMEAN / 1000.0


* Add wind

merge 1:1  year month day hour using "$dirpath/data/input/data_wind_speed_merra.dta", keep(1 3) nogen


* Add carbon pricies

merge m:1 year month day using "$dirpath/data/input/EU_ETS_prices.dta", keep(1 3) nogen

sort year month day hour
fillmissing C_price, with(previous)


* Adding month- and day-of-sample indicators

egen day_of_sample = group(year month day)
egen month_of_sample = group(year month)

* Save the data for the regression analysis 
order year month day hour dayofweek 
sort year month day hour

* Label VARIABLES
label variable restrictionsDA "Day-Ahead adjustment costs (EUR/MWh)"
label variable restrictionsRT "Real-time adjustment costs (EUR/MWh)"
label variable reserve "Reserve costs (EUR/MWh)"
label variable secondary "Secondary costs (EUR/MWh)"
label variable netdeviations "(mean) netdeviations (EUR/MWh)"
label variable costdeviations "(mean) costdeviations (EUR/MWh)"
label variable po14 "Costs from international exchanges adjustments (EUR/MWh)"
label variable wind_final "Final wind production (GWh)"
label variable wind_forecast "Forecasted wind (GWh)"
label variable wind_final "Final wind production (GWh)"
label variable wind_dev "Wind deviation planned vs delivered (GWh)"
label variable totalcost "Operational cost (EUR/MWh)"
label variable actual_demand "Realized demand (GWh)"
label variable forecast_demand "Forecasted demand (GWh)"
label variable demand_forecast "Forecasted demand (GWh)"
label variable errorforecast_demand "(mean) errorforecast_demand (GWh)"
label variable demand_forecast "Forecasted demand (GWh)"
label variable congestion_cost "Congestion costs (EUR/MWh)"
label variable adjustment_cost "Adjustment costs (EUR/MWh)"
label variable insurance_cost "Regulation costs (EUR/MWh)"
label variable vol1 "(mean) vol1 (GWh)"
label variable vol2 "(mean) vol2 (GWh)"
label variable vol6 "(mean) vol6 (GWh)"
label variable vol12 "(mean) vol12 (GWh)"
label variable vol24 "Volatility 24-hr (GWh)"
label variable volabs1 "(mean) volabs1 (GWh)"
label variable volabs2 "(mean) volabs2 (GWh)"
label variable volabs6 "(mean) volabs6 (GWh)"
label variable volabs12 "(mean) volabs12 (GWh)"
label variable volabs24 "(mean) volabs24 (GWh)"
label variable wind_change_forecast "(mean) wind_change_forecast (GWh)"
label variable wind_change_forecast_abs "(mean) wind_change_forecast_abs (GWh)"
label variable unc6 "(mean) unc6 (GWh)"
label variable unc12 "(mean) unc12 (GWh)"
label variable unc24 "Uncertainty 24-hr (GWh)"
label variable unc36 "(mean) uncabs36 (GWh)"
label variable uncabs6 "(mean) uncabs6 (GWh)"
label variable uncabs12 "(mean) uncabs12 (GWh)"
label variable uncabs24 "(mean) uncabs24 (GWh)"
label variable uncabs36 "(mean) volabs36 (GWh)"
label variable ng_spot_p "NG price (EUR/MWh)"
label variable price_wind "Net price for wind (EUR/MWh)"
label variable photov_final "Solar production (GWh)"
label variable tempMEAN "Mean temperature (F)"
label variable tempMEANsq "Sq. mean temp. (F/1000)"
label variable dewMEAN  "Mean dew point (F)"
label variable humidMEAN  "Mean humidity"
label variable C_price  "Carbon price EUR/ton"


foreach i in 6 12 24 36 {
	label var unc`i' "Abs. Uncertainty `i'-hr"
	label var uncabs`i' "SD Uncertainty `i'-hr"
}

foreach i in 1 2 6 12 24 {
	label var vol`i' "Abs. Uncertainty `i'-hr"
	label var volabs`i' "SD Uncertainty `i'-hr"
}

keep if year>=$startYear
keep if year<=$endYear

* keep only if relevant variables observed
global controls_8 demand_forecast ng_spot_p tempMEAN tempMEANsq dewMEAN photov_final
foreach var of varlist $controls_8 {
	drop if `var'==.
}
	
compress
sort year month day hour
*save "data_costs_intermittency.dta", replace
cd "$dirpath/data/output/"
save "data_costs_intermittency.dta", replace

*** END OF FILE
