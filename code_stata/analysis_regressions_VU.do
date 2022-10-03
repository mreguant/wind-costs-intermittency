/*******************************************************************************

	Name: analysis_regressions_VU.do
	
	Goal: Run intermittency regressions and assemble a database of margins and averages.

*******************************************************************************/


	clear all
	set type double
	set more off
	program drop _all
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
	
	* dependent variables
	rename totalcost tcost
	rename congestion_cost ccost
	rename adjustment_cost acost
	rename insurance_cost icost
	
	global costs tcost ccost acost icost
	global costsh tcost
	gen finalp = price0 + tcost + capacity_pay
	global prices finalp price_wind
	global em emis_tCO2
	
	* observe different hours
	global hourly 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
	global nums5 1 2 3 4 5
	global nums10 1 2 3 4 5 6 7 8 9 10
	global numsyr 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 
	global numshr 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
	global circuit 5 25 50 70 90 95
	global yrs_smol 2012 2014 2015 2018
	global clustvar month_of_sample

	* TIP: can generate splines using this
	mkspline windsp 5 = wind_forecast
	global wind_quint windsp1 windsp2 windsp3 windsp4 windsp5
	global wind_quint_unc c.windsp1#c.unc24 c.windsp2#c.unc24 c.windsp3#c.unc24 c.windsp4#c.unc24 c.windsp5#c.unc24
	global wind_quint_vol c.windsp1#c.vol24 c.windsp2#c.vol24 c.windsp3#c.vol24 c.windsp4#c.vol24 c.windsp5#c.vol24
	

	* Prep for percentiles at margins
	_pctile unc24, p(50)
	local unc24_50 = `r(r1)'
	_pctile vol24, p(50)
	local vol24_50 = `r(r1)'
	foreach c in $circuit {
		_pctile unc24, p(`c')
		local unc24 = `r(r1)'
		_pctile vol24, p(`c')
		local vol24 = `r(r1)'
		global mgs1_`c' = "unc24=`unc24' vol24=`vol24_50'"
		global mgs2_`c' = "unc24=`unc24_50' vol24=`vol24'"
		global mgs3_`c' = "unc24=`unc24' vol24=`vol24'"
	}
	forvalues w = 1(1)5 {
		_pctile unc24 if wind_5==`w', p(50)
		local unc24_50 = `r(r1)'
		_pctile vol24 if wind_5==`w', p(50)
		local vol24_50 = `r(r1)'
		foreach c in $circuit {
			_pctile unc24 if wind_5==`w', p(`c')
			local unc24 = `r(r1)'
			_pctile vol24 if wind_5==`w', p(`c')
			local vol24 = `r(r1)'
			global mgs1`w'_`c' = "unc24=`unc24' vol24=`vol24_50'"
			global mgs2`w'_`c' = "unc24=`unc24_50' vol24=`vol24'"
			global mgs3`w'_`c' = "unc24=`unc24' vol24=`vol24'"
		}
	}

/*******************************************************************************

	VU Spline Regressions

*******************************************************************************/


	postutil clear

	tempname regResults
	postfile `regResults' str20(yvar spec fe controls effect label unc vol) double(xvalue yvalue ci_lb ci_ub) ///
		using "$dirpath/results/results_VU_regressions.dta", replace

	* $costs $prices $em
	foreach yvar in tcost {
		foreach fe in "fe_yr" "fe_sh" "fe_long" "fe_hr_2" {
			di "Running `yvar' with `fe'"
			forvalues c = 5(1)5 {
				
				qui reghdfe `yvar' $wind_quint $wind_quint_unc $wind_quint_vol ${controls_`c'}, ///
					absorb(${`fe'}) vce(cluster $clustvar) 
				est store spec1
				
				qui reghdfe `yvar' $wind_quint_unc $wind_quint_vol ${controls_`c'}, ///
					absorb(${`fe'}) vce(cluster $clustvar) 
				est store spec2

				forvalues d = 1(1)2 {
					est restore spec`d'
					* margins
					foreach x in $nums5 {
						foreach y in $circuit {
						qui margins , dydx(windsp`x') at("${mgs1_`y'}")
						post `regResults' ("`yvar'") ("VU_`d' spline") ("`fe'") ("`c'") ///
							("margins_unc") ("windsp`x'") ("`y'") ("50") (`x') (r(b)[1,1]) ///
							(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
							(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
						qui margins , dydx(windsp`x') at("${mgs2_`y'}")
						post `regResults' ("`yvar'") ("VU_`d' spline") ("`fe'") ("`c'") ///
							("margins_vol") ("windsp`x'") ("50") ("`y'") (`x') (r(b)[1,1]) ///
							(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
							(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
						qui margins , dydx(windsp`x') at("${mgs3_`y'}")
						post `regResults' ("`yvar'") ("VU_`d' spline") ("`fe'") ("`c'") ///
							("margins_VU") ("windsp`x'") ("`y'") ("`y'") (`x') (r(b)[1,1]) ///
							(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
							(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))	
						}
					}
					* averages
					foreach x in $nums5 {	
						foreach y in $circuit {
						qui margins if wind_5==`x',  at("${mgs1`x'_`y'}")
						post `regResults' ("`yvar'") ("VU_`d' spline") ("`fe'") ("`c'") ///
							("averages_unc") ("windsp`x'") ("`y'") ("50") (`x') (r(b)[1,1]) ///
							(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
							(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
						qui margins if wind_5==`x', at("${mgs2`x'_`y'}")
						post `regResults' ("`yvar'") ("VU_`d' spline") ("`fe'") ("`c'") ///
							("averages_vol") ("windsp`x'") ("50") ("`y'") (`x') (r(b)[1,1]) ///
							(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
							(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
						qui margins if wind_5==`x', at("${mgs3`x'_`y'}")
						post `regResults' ("`yvar'") ("VU_`d' spline") ("`fe'") ("`c'") ///
							("averages_VU") ("windsp`x'") ("`y'") ("`y'") (`x') (r(b)[1,1]) ///
							(r(b)[1,1] - 1.96 * sqrt(r(V)[1,1])) ///
							(r(b)[1,1] + 1.96 * sqrt(r(V)[1,1]))
						}
					}
				}
				
			}
		}
	}
	postclose `regResults'
