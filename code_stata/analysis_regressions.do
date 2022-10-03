/*******************************************************************************

	Name: analysis_regressions.do
	
	Goal: Run spline + welfare regressions and assemble a database of margins and averages.

*******************************************************************************/


	clear all
	set type double
	set more off
	set maxvar 32767

/*******************************************************************************

	0. Preface

*******************************************************************************/
	
	
	cd "$dirpath/data/output/"
	use "data_costs_intermittency.dta", clear

	
	* Define global variables
	
	* different time FE
	gen one1 = 1
	global ones one1
	global fe_sh i.month_of_sample
	global fe_yr i.year##i.hour
	global fe_yr_shift i.year_shift##i.hour
	global fe_long i.month
	global fe_long_hr i.month##i.hour
	* note to self i.hour#c.wind
	global fe_hr i.month_of_sample i.hour
	global fe_hr_2 i.month_of_sample##i.hour
	
	
	gen year_shift = year
	replace year_shift = year - 1 if month < 6
	
	* different sets of control variables
	global controls_1 demand_forecast photov_final
	global controls_2 demand_forecast photov_final ng_spot_p
	global controls_3 demand_forecast photov_final ng_spot_p tempMEAN
	global controls_4 demand_forecast photov_final ng_spot_p tempMEAN tempMEANsq
	global controls_5 demand_forecast photov_final ng_spot_p tempMEAN tempMEANsq dewMEAN
	global controls_6 demand_forecast photov_final ng_spot_p tempMEAN tempMEANsq dewMEAN humidMEAN
	global controls_yr demand_forecast tempMEAN tempMEANsq dewMEAN photov_final
	global controls_m_pho demand_forecast ng_spot_p tempMEAN tempMEANsq dewMEAN
	global controls_fun c.demand_forecast#i.hour ng_spot_p tempMEAN tempMEANsq dewMEAN photov_final
	global controls_m_dem ng_spot_p tempMEAN tempMEANsq dewMEAN photov_final
	
	* dropping missing data to ensure consistency of sample
	foreach var of varlist $controls_5 {
		drop if `var'==.
	}
	
	* dependent variables
	rename totalcost tcost
	rename congestion_cost ccost
	rename adjustment_cost acost
	rename insurance_cost icost
	
	global costs tcost ccost acost icost
	global costsh tcost
	gen finalp = price0 + tcost + capacity_pay
	gen pdiff = price_wind - price0
	gen pdiff2 = finalp - price0
	gen cost_wind = price0 - price_wind
	global prices finalp price0 price_wind pdiff pdiff2
	global prices_welfare finalp price0 price_wind cost_wind
	global em emis_tCO2
	
	* observe different hours
	global hourly 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
	global nums5 1 2 3 4 5
	global nums10 1 2 3 4 5 6 7 8 9 10
	global numsyr 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018
	global numshr 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
	global circuit p5 p25 p50 p70 p90 p95
	global yrs_smol 2012 2014 2015 2018
	global clustvar month_of_sample

	* TIP: can generate splines using this
	mkspline windsp 5 = wind_forecast
	global wind_quint windsp1 windsp2 windsp3 windsp4 windsp5

	*prep for averages_2
	tabstat wind_forecast, by(wind_5) stats(mean max) save
	local wind1 = r(Stat1)[1,1]
	local wind_max1 = r(Stat1)[2,1]

	forvalues w = 2(1)5 {
		local v = `w' - 1
		local wind`w' = r(Stat`w')[1,1]
		local wind_max`w' = r(Stat`w')[2,1] - r(Stat`v')[2,1]
		local wind_inc`w' = r(Stat`w')[1,1] - r(Stat`v')[2,1]
	}

	global mgs1 = "windsp1=`wind1' windsp2=0 windsp3=0 windsp4=0 windsp5=0"
	global mgs2 = "windsp1=`wind_max1' windsp2=`wind_inc2' windsp3=0 windsp4=0 windsp5=0"
	global mgs3 = "windsp1=`wind_max1' windsp2=`wind_max2' windsp3=`wind_inc3' windsp4=0 windsp5=0"
	global mgs4 = "windsp1=`wind_max1' windsp2=`wind_max2' windsp3=`wind_max3' windsp4=`wind_inc4' windsp5=0"
	global mgs5 = "windsp1=`wind_max1' windsp2=`wind_max2' windsp3=`wind_max3' windsp4=`wind_max4' windsp5=`wind_inc5'"
			
/*******************************************************************************

	1. Wind Spline Regressions

*******************************************************************************/
	postutil clear

	tempname regResults
	postfile `regResults' str20(yvar spec fe controls effect label) double(xvalue yvalue ci_lb ci_ub) ///
		using "$dirpath/results/results_spline_regressions.dta", replace
		
	foreach yvar in $costs $prices $em {
		foreach fe in "fe_yr" "fe_sh" "fe_long" "fe_hr_2" "fe_long_hr" {
			forvalues c = 1(1)6 {
				qui reghdfe `yvar' $wind_quint ${controls_`c'}, ///
					absorb(${`fe'}) vce(cluster $clustvar)

				* margins
				foreach x in $nums5 {
					qui margins , dydx(windsp`x')
					post `regResults' ("`yvar'") ("spline") ("`fe'") ("`c'") ///
						("margins") ("windsp`x'") (`x') (r(b)[1,1]) ///
						(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
						(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
				}
				
				* averages
				forvalues x = 1(1)5 {
					qui margins , at("${mgs`x'}") 
					post `regResults' ("`yvar'") ("spline") ("`fe'") ("`c'") ///
						("averages_at_mgswind") ("windsp`x'") (`x') (r(b)[1,1]) ///
						(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
						(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
				}
			}
		}
	}
	postclose `regResults'

/*******************************************************************************

	2. Wind Years Regressions

*******************************************************************************/
	
	postutil clear

	tempname regResults2
	postfile `regResults2' str20(yvar spec fe controls effect label) double(xvalue yvalue ci_lb ci_ub) ///
		using "$dirpath/results/results_yr_regressions.dta", replace

	foreach yvar in $costs $prices $em {
		foreach fe in "fe_yr" "fe_sh" "fe_long" "fe_hr_2" "fe_long_hr" {
			forvalues c = 5(1)5 {
				
				qui reghdfe `yvar' c.wind_forecast#i.year ${controls_`c'}, ///
					absorb(${`fe'}) vce(cluster $clustvar) 

				* margins
				foreach x in $numsyr {
					qui margins year if year == `x', dydx(wind_forecast)
					post `regResults2' ("`yvar'") ("yr_interaction") ("`fe'") ("`c'") ///
						("margins") ("year") (`x') (r(b)[1,1]) ///
						(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
						(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
				}
				
				* averages
				foreach x in $numsyr {
					qui margins , at(year == `x')
					post `regResults2' ("`yvar'") ("yr_interaction") ("`fe'") ("`c'") ///
						("averages_at") ("year") (`x') (r(b)[1,1]) ///
						(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
						(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
				}
			}
		}
	}
	postclose `regResults2'
	
	postutil clear

	tempname regResults2
	postfile `regResults2' str20(yvar spec fe controls effect label) double(xvalue yvalue ci_lb ci_ub) ///
		using "$dirpath/results/results_yr_shift_regressions.dta", replace
		
	preserve

	
	foreach yvar in $costs $prices $em {
		foreach fe in "fe_yr_shift" "fe_sh" "fe_long" "fe_hr_2" "fe_long_hr" {
			forvalues c = 5(1)5 {
				
				qui reghdfe `yvar' c.wind_forecast#i.year_shift ${controls_`c'}, ///
					absorb(${`fe'}) vce(cluster $clustvar) 

				* margins
				foreach x in $numsyr {
					qui margins year_shift if year_shift == `x', dydx(wind_forecast)
					post `regResults2' ("`yvar'") ("yr_interaction") ("`fe'") ("`c'") ///
						("margins") ("year_shift") (`x') (r(b)[1,1]) ///
						(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
						(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
				}
				
				* averages
				foreach x in $numsyr {
					qui margins , at(year_shift == `x')
					post `regResults2' ("`yvar'") ("yr_interaction") ("`fe'") ("`c'") ///
						("averages_at") ("year_shift") (`x') (r(b)[1,1]) ///
						(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
						(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
				}
			}
		}
	}
	
	restore
	
	postclose `regResults2'
	
/*******************************************************************************

	3. Welfare analysis regressions

*******************************************************************************/
	
	* Generating useful metrics for welfare
			
	* Traditional PS = 0.5*(Qdemand-Qwind)*(P2-P1) - 0.5*P1 - .05*(P2-P1)
	* Where P is price_0
	gen price0_tdemand = price0 * (actual_demand - wind)
		* ^ need both averages and margins on him
		
	* Wind Farm PS = Qwind*(P2-P1) + P1 + (P2-P1)
	* Where P is price_wind
	gen price_wind_wdemand = price_wind * wind
	gen price0_wdemand = price0 * wind
	
	* Emissions
	gen emis_1 = C_price * emis_tCO2 / 1000.0
	gen emis_2 = emis_tCO2 / 1000.0
	
	* Overall electricity costs (with and without intermittency to see impact)
	foreach var of varlist finalp price0 {
		gen `var'_demand = `var' * actual_demand
	}
		
	
	postutil clear

	
	* LINEAR 
	tempname regResults_linear
	postfile `regResults_linear' str20(yvar spec fe controls effect label) double(yvalue ci_lb ci_ub) ///
		using "$dirpath/results/results_linear_welfare_regressions_NEW.dta", replace

	tempname regResults_IV
	postfile `regResults_IV' str20(yvar spec fe controls effect label) double(yvalue ci_lb ci_ub) ///
		using "$dirpath/results/results_IV_welfare_regressions_NEW.dta", replace
		
	foreach yvar in emis_1 emis_2 price0_tdemand price0 price_wind_wdemand price0_wdemand price_wind finalp_demand price0_demand subsidy_cost {
		cap foreach fe in "fe_sh" "fe_yr_shift" {
			forvalues c = 5(1)5 {
				qui reghdfe `yvar' wind_forecast ${controls_`c'}, ///
					absorb(${`fe'}) vce(cluster $clustvar) 

				* margins
					qui margins , dydx(wind_forecast)
					post `regResults_linear' ("`yvar'") ("linear") ("`fe'") ("`c'") ///
						("margins") ("welfare") (r(b)[1,1]) ///
						(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
						(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
				
					if ("`yvar'"=="price0") {
						qui margins , at((median) wind_forecast)
						post `regResults_linear' ("`yvar'") ("linear") ("`fe'") ("`c'") ///
							("average") ("welfare") (r(b)[1,1]) ///
							(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
							(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
					
					}
						
			}
			
			* IV
			forvalues c = 5(1)5 {
				qui ivregress 2sls `yvar' (wind=wp50_wcapadj) ${controls_`c'} ///
					${`fe'}, cluster($clustvar) 
				*qui ivreghdfe `yvar' (wind=wp50_wcapadj) ${controls_`c'}, ///
				*	absorb(${`fe'}) cluster($clustvar) 
					
				* margins
					qui margins , dydx(wind)
					post `regResults_IV' ("`yvar'") ("IV") ("`fe'") ("`c'") ///
						("margins") ("welfare") (r(b)[1,1]) ///
						(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
						(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
						
					if ("`yvar'"=="price0") {
						qui margins , at((median) wind)
						post `regResults_IV' ("`yvar'") ("IV") ("`fe'") ("`c'") ///
							("average") ("welfare") (r(b)[1,1]) ///
							(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
							(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
					
					}							
						
			}
		}
	}
	postclose `regResults_linear'
	postclose `regResults_IV'
	
	
	* SPLINE
	tempname regResults3
	postfile `regResults3' str20(yvar spec fe controls effect label) double(xvalue yvalue ci_lb ci_ub) ///
		using "$dirpath/results/results_spline_welfare_regressions_NEW.dta", replace

	foreach yvar in emis_1 emis_2 price0_tdemand price0 price_wind_wdemand price0_wdemand price_wind finalp_demand price0_demand subsidy_cost {
		cap foreach fe in "fe_sh" "fe_hr_2" "fe_yr_shift" {
			forvalues c = 5(1)5 {
				
				qui reghdfe `yvar' $wind_quint ${controls_`c'}, ///
					absorb(${`fe'}) vce(cluster $clustvar) 

				* margins
				foreach x in $nums5 {
					qui margins , dydx(windsp`x')
					post `regResults3' ("`yvar'") ("spline") ("`fe'") ("`c'") ///
						("margins") ("welfare") (`x') (r(b)[1,1]) ///
						(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
						(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
				
					if ("`yvar'"=="price0") {
						qui margins , at("${mgs`x'}") 
						post `regResults3' ("`yvar'") ("spline") ("`fe'") ("`c'") ///
							("average") ("welfare") (`x') (r(b)[1,1]) ///
							(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
							(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
					
					}
						
				}
			}
		}
	}
	postclose `regResults3'

	
******************************************************************************
