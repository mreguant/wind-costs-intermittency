/*******************************************************************************

	Name: analysis_tables.do
	
	Goal: Create tables based on different specifications of baseline regression

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
	global fe_sh i.year#i.month
	global fe_long i.month
	global fe_long_hr i.month#i.hour
	* note to self i.hour#c.wind
	global fe_hr i.year#i.month i.hour
	global fe_hr_2 i.year#i.month#i.hour
	
	* clustering
	global clustvar month_of_sample
	
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
	foreach var of varlist $controls_6 {
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
	global prices finalp price_wind
	global em emis_tCO2
	
	* observe different hours
	global hourly 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
	global nums5 1 2 3 4 5
	global nums10 1 2 3 4 5 6 7 8 9 10
	global numsyr 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019
	global numshr 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
	global circuit p5 p25 p50 p70 p90 p95
	global yrs_smol 2012 2014 2015 2018
	global clustvar month_of_sample
								
			
/*******************************************************************************

	Controls Table

*******************************************************************************/
qui reghdfe tcost wind_forecast $controls_1, absorb($fe_hr_2) vce(cluster $clustvar) 
outreg2 using "$dirpath/tables/table_controls3.doc", tex(frag) replace  ///
	keep(wind_forecast $controls_1) addtext() noaster label nonotes nocons ctitle(" ")
	
global cont 2 4 5
foreach c in $cont {
	qui reghdfe tcost wind_forecast ${controls_`c'}, absorb($fe_hr_2) vce(cluster $clustvar) 
	
	outreg2 using "$dirpath/tables/table_controls3.doc", tex(frag) noaster label  ctitle(" ") ///
	keep(wind_forecast ${controls_`c'}) append nonotes nocons
}

/*******************************************************************************

	FE Table

*******************************************************************************/

	* different time FE

	qui reg tcost wind_forecast $controls_5, cluster($clustvar) 
	outreg2 using "$dirpath/tables/table_fe.doc", tex(frag) replace noaster label nonotes nocons ctitle(" ") ///
	keep(wind_forecast demand_forecast photov_final) addtext(Year FE, No, Month FE, No, Hour FE, No)

	qui reghdfe tcost wind_forecast $controls_5, absorb(i.year) vce(cluster $clustvar) 
	outreg2 using "$dirpath/tables/table_fe.doc", tex(frag) append noaster label nonotes nocons ctitle(" ") ///
	keep(wind_forecast demand_forecast photov_final) addtext(Year FE, Yes, Month FE, No, Hour FE, No)

	qui reghdfe tcost wind_forecast $controls_5, absorb($fe_long) vce(cluster $clustvar) 
	outreg2 using "$dirpath/tables/table_fe.doc", tex(frag) append  noaster label nonotes nocons ctitle(" ") ///
	keep(wind_forecast demand_forecast photov_final) addtext(Year FE, No, Month FE, Yes, Hour FE, No)
	
	qui reghdfe tcost wind_forecast $controls_5, absorb($fe_sh) vce(cluster $clustvar) 
	outreg2 using "$dirpath/tables/table_fe.doc", tex(frag) append noaster label nonotes nocons ctitle(" ") ///
	keep(wind_forecast demand_forecast photov_final) addtext(Year FE, Yes, Month FE, Yes, Hour FE, No)
	
	qui reghdfe tcost wind_forecast $controls_5, absorb($fe_long_hr) vce(cluster $clustvar) 
	outreg2 using "$dirpath/tables/table_fe.doc", tex(frag) append noaster label nonotes nocons ctitle(" ") ///
	keep(wind_forecast demand_forecast photov_final) addtext(Year FE, No, Month FE, Yes, Hour FE, Yes)

	qui reghdfe tcost wind_forecast $controls_5, absorb($fe_hr_2) vce(cluster $clustvar) 
	outreg2 using "$dirpath/tables/table_fe.doc", tex(frag) append noaster label nonotes nocons ctitle(" ") ///
	keep(wind_forecast demand_forecast photov_final) addtext(Year FE, Yes, Month FE, Yes, Hour FE, Yes)

/*******************************************************************************

	Daily Controls Table

*******************************************************************************/
	
	preserve 
		
	summ demand_forecast
	local mean_d `r(mean)'
	
	gen tcost_000 = tcost * demand_forecast 
	gcollapse (sum) tcost_000 wind_forecast demand_forecast photov_final ///
		(mean) ng_spot_p  temp* dewMEAN, ///
		labelformat(#sourcelabel#) by(year month day month_of_sample dayofweek)

	* controls daily
	qui reghdfe tcost wind_forecast $controls_1, absorb(i.month_of_sample) vce(cluster $clustvar) 
	local effect = _b[wind_forecast]/`mean_d'
	local effectd: display %4.3f `effect'
	outreg2 using "$dirpath/tables/table_controls3_daily.doc", tex(frag) replace  ///
		keep(wind_forecast $controls_1) addtext(Implied average effect, `effectd') noaster label nonotes nocons ctitle(" ")
	
	global cont 2 4 5
	foreach c in $cont {
		qui reghdfe tcost wind_forecast ${controls_`c'}, absorb(i.month_of_sample) vce(cluster $clustvar) 
		local effect = _b[wind_forecast]/`mean_d'
		local effectd: display %4.3f `effect'
		outreg2 using "$dirpath/tables/table_controls3_daily.doc", tex(frag) noaster label  ctitle(" ") ///
		keep(wind_forecast ${controls_`c'}) addtext(Implied average effect, `effectd') append nonotes nocons
	}


	restore

/*******************************************************************************

	Wind Forecast vs Final Appendix Table

*******************************************************************************/
	
	
qui reghdfe tcost wind_forecast $controls_5, absorb($fe_hr_2) vce(cluster $clustvar) 
outreg2 using "$dirpath/tables/table_wind.doc", tex(frag) replace noaster label nonotes nocons ctitle(Wind Forecast) ///
keep(wind_forecast) addtext()

qui reghdfe tcost wind_final $controls_5, absorb($fe_hr_2) vce(cluster $clustvar) 
outreg2 using "$dirpath/tables/table_wind.doc", tex(frag) append noaster label nonotes nocons ctitle(Wind) ///
keep(wind_final) addtext()

ivreghdfe tcost (wind_final=wind_forecast) $controls_5, absorb($fe_hr_2) cluster($clustvar) 
outreg2 using "$dirpath/tables/table_wind.doc", tex(frag) append noaster label nonotes nocons ctitle(IV Forecast) ///
keep(wind_final) addtext()

ivreghdfe tcost (wind_final=wp50_wcapadj) $controls_5, absorb($fe_hr_2) cluster($clustvar) 
outreg2 using "$dirpath/tables/table_wind.doc", tex(frag) append noaster label nonotes nocons ctitle(IV Power) ///
keep(wind_final) addtext()



/*******************************************************************************

	Wind Production vs Speed in Policy Change

*******************************************************************************/
	
gen flag = "Pre comparison"
replace flag = "1 - Pre June 6, 2014" if (year == 2013 & month == 6 & day > 6) | (year == 2013 & month > 6)  | (year==2014)
replace flag = "2 - Post June 6, 2014" if (year == 2014 & month == 6 & day > 6) | (year == 2014 & month > 6) | (year==2015)
replace flag = "Post comparison" if (year == 2015 & month == 6 & day > 6) | (year == 2015 & month > 6) | year > 2015	

preserve 

keep if flag == "1 - Pre June 6, 2014" | flag == "2 - Post June 6, 2014"

encode flag, gen(flag_id)

qui reghdfe wind c.wp50_wcapadj#i.flag_id $controls_1, absorb($fe_hr_2) vce(cluster $clustvar) 
outreg2 using "$dirpath/tables/table_wind_policy.doc", tex(frag) replace  ///
	keep(c.wp50_wcapadj#i.flag_id $controls_1) addtext() noaster label nonotes nocons ctitle(" ")
	
global cont 2 4 5
foreach c in $cont {
	qui reghdfe wind c.wp50_wcapadj#i.flag_id ${controls_`c'}, absorb($fe_hr_2) vce(cluster $clustvar) 
	
	outreg2 using "$dirpath/tables/table_wind_policy.doc", tex(frag) noaster label  ctitle(" ") ///
	keep(c.wp50_wcapadj#i.flag_id wind_forecast ${controls_`c'}) append nonotes nocons
}

restore
