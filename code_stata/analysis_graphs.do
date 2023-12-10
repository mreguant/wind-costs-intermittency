/*******************************************************************************

	Name: analysis_graphs.do
	
	Goal: Graph regression outputs.

*******************************************************************************/


	clear all
	set type double
	set more off
	program drop _all
	set maxvar 32767
	
	global controls_1 demand_forecast photov_final
	global controls_2 demand_forecast photov_final ng_spot_p
	global controls_3 demand_forecast photov_final ng_spot_p tempMEAN
	global controls_4 demand_forecast photov_final ng_spot_p tempMEAN tempMEANsq
	global controls_5 demand_forecast photov_final ng_spot_p tempMEAN tempMEANsq dewMEAN
	global controls_6 demand_forecast photov_final ng_spot_p tempMEAN tempMEANsq dewMEAN humidMEAN

	global fe_choice = "fe_hr_2"
	global fe_shift = "fe_sh"
	
/*******************************************************************************

	0. Creating Wind_5_50.dta

*******************************************************************************/
	* Store the Wind_5 median values
	cd "$dirpath/data/output/"
	use "data_costs_intermittency.dta", clear

	* dropping missing data to ensure consistency of sample
	foreach var of varlist $controls_5 {
		drop if `var'==.
	}
	bysort wind_5: egen tcost_5 = mean(totalcost)
	bysort wind_5: egen temis_5 = mean(emis_tCO2)		
	bysort wind_5: egen wind_5_50 = mean(wind_forecast)
	mkspline windsp 5 = wind_forecast , pctile
	forvalues c = 1(1)5 {
		bysort wind_5: egen windsp`c'max = max(windsp`c')
		drop windsp`c'
	}
	keep  wind_5_50 wind_5 tcost_5 temis_5 windsp1max windsp2max windsp3max windsp4max windsp5max
	rename wind_5 xvalue
	duplicates drop
	drop if xvalue == .
	replace windsp5max = (wind_5_50 - windsp1max - windsp2max - windsp3max - windsp4max) if xvalue == 5
	replace windsp4max = (wind_5_50 - windsp1max - windsp2max - windsp3max) if xvalue == 4
	replace windsp3max = (wind_5_50 - windsp1max - windsp2max) if xvalue == 3
	replace windsp2max = (wind_5_50 - windsp1max) if xvalue == 2
	replace windsp1max = wind_5_50 if xvalue == 1
	save "wind_5_50.dta", replace

/*******************************************************************************

	1. Regular Spline Graphs

*******************************************************************************/
	
	* Merge the median values with the regression results
	use "$dirpath/results/results_spline_regressions.dta", clear
	merge m:1 xvalue using "wind_5_50.dta", nogen

* NOTE on Graph Naming: "Spec FE Controls YVar Effect.pdf"	
	/***************************************************************************
	   1.1. Costs Graph
	***************************************************************************/ 
	preserve
	keep if (yvar == "tcost" | yvar == "ccost" | yvar == "icost" | yvar == "acost") & spec == "spline" & fe=="$fe_choice" & controls=="5" & effect != "averages_cond"
	replace effect = "Cost Margins (EUR/MWh)" if effect == "margins"
	replace effect = "Cost Averages (EUR/MWh)" if effect == "averages_at_mgswind"
	***************************************************************************
	twoway 	(rcap ci_lb ci_ub wind_5_50 if yvar == "tcost", by(effect) color(navy)) || ///
			(rcap ci_lb ci_ub wind_5_50 if yvar == "ccost", by(effect) color(ebblue)) || ///
			(rcap ci_lb ci_ub wind_5_50 if yvar == "icost", by(effect) color(eltblue)) || ///
			(rcap ci_lb ci_ub wind_5_50 if yvar == "acost", by(effect) color(eltgreen)) || ///
			(line yvalue wind_5_50 if yvar == "tcost", by(effect, col(1) yrescale note("") graphregion(color(white))) color(navy)) || ///
			(line yvalue wind_5_50 if yvar == "ccost", by(effect) color(ebblue)) || ///
			(line yvalue wind_5_50 if yvar == "icost", by(effect) color(eltblue)) || ///
			(line yvalue wind_5_50 if yvar == "acost", by(effect) color(eltgreen)) || ///
			, graphregion(color(white)) ///
			legend(size(*.8) symxsize(*.6) order(1 "operational costs (all)" 2 "restrictions cost" 3 "frequency cost" 4 "deviations cost") row(1)) ///
			ytitle("") xtitle("Wind (GWh)",size(small)) ///
			xlabel(#10, labsize(vsmall)) ylabel(,angle(90) labsize(vsmall))
			graph export "$dirpath/figures/Spline_FeHr2_C5_Costs_Margins_Averages.pdf", as(pdf) replace
	***************************************************************************
	restore

	
	/***************************************************************************
	   1.2 Wholesale Market Price Graph 
	***************************************************************************/ 
	preserve
	keep if (yvar == "price0" | yvar == "finalp" | yvar == "pdiff2") & spec == "spline" & fe=="$fe_choice" & controls=="5" & effect != "averages_cond"
	replace effect = "Price Margins (EUR/MWh)" if effect == "margins"
	replace effect = "Price Averages (EUR/MWh)" if effect == "averages_at_mgswind"
	***************************************************************************
	twoway 	(rcap ci_lb ci_ub wind_5_50 if yvar == "finalp", by(effect) color(navy)) || ///
			(rcap ci_lb ci_ub wind_5_50 if (yvar == "price0" & effect == "Price Averages (EUR/MWh)"), color(ebblue)) || ///
			(rcap ci_lb ci_ub wind_5_50 if (yvar == "pdiff2" & effect == "Price Margins (EUR/MWh)"), color(eltgreen)) || ///
			(line yvalue wind_5_50 if yvar == "finalp", by(effect, col(1) yrescale note("") graphregion(color(white))) color(navy)) || ///
			(line yvalue wind_5_50 if (yvar == "price0" & effect == "Price Averages (EUR/MWh)"), color(ebblue)) || ///
			(line yvalue wind_5_50 if (yvar == "pdiff2" & effect == "Price Margins (EUR/MWh)"), color(eltgreen)) || ///
			, graphregion(color(white)) ///
			legend(size(*.8) symxsize(*.6) order(1 "wholesale price" 2 "day ahead price" 3 "wholesale price minus DA price") row(1)) ///
			ytitle("") xtitle("Wind (GWh)",size(small)) ///
			xlabel(#10, labsize(vsmall)) ylabel(,angle(90) labsize(vsmall))
			graph export "$dirpath/figures/Spline_FeHr2_C5_Price2_Margins_Averages.pdf", as(pdf) replace
	***************************************************************************
	restore
	
	/***************************************************************************
	   1.2.5 Revenues Price Graph 
	***************************************************************************/ 
	preserve
	keep if (yvar == "price_wind" | yvar == "price0" | yvar == "pdiff") & spec == "spline" & fe=="$fe_choice" & controls=="5" & effect != "averages_cond"
	replace effect = "Price Margins (EUR/MWh)" if effect == "margins"
	replace effect = "Price Averages (EUR/MWh)" if effect == "averages_at_mgswind"
	***************************************************************************
	twoway 	(rcap ci_lb ci_ub wind_5_50 if yvar == "price_wind", by(effect) color(navy)) || ///
			(rcap ci_lb ci_ub wind_5_50 if (yvar == "price0" & effect == "Price Averages (EUR/MWh)"), color(ebblue)) || ///
			(rcap ci_lb ci_ub wind_5_50 if (yvar == "pdiff" & effect == "Price Margins (EUR/MWh)"), color(eltgreen)) || ///
			(line yvalue wind_5_50 if yvar == "price_wind", by(effect, col(1) yrescale note("") graphregion(color(white))) color(navy)) || ///
			(line yvalue wind_5_50 if (yvar == "price0" & effect == "Price Averages (EUR/MWh)"), color(ebblue)) || ///
			(line yvalue wind_5_50 if (yvar == "pdiff" & effect == "Price Margins (EUR/MWh)"), color(eltgreen)) || ///
			, graphregion(color(white)) ///
			legend(size(*.8) symxsize(*.6) order(1 "generator's price" 2 "day ahead price" 3 "deviations costs") row(1)) ///
			ytitle("") xtitle("Wind (GWh)",size(small)) ///
			xlabel(#10, labsize(vsmall)) ylabel(,angle(90) labsize(vsmall))
			graph export "$dirpath/figures/Spline_FeHr2_C5_Price3_Margins_Averages.pdf", as(pdf) replace
	***************************************************************************
	restore

	/***************************************************************************
	   1.3. Emissions Graph
	***************************************************************************/ 
	preserve
	keep if (yvar == "emis_tCO2") & spec == "spline" & fe=="$fe_choice" & controls=="5" & effect != "averages_cond"
	replace effect = "Emissions Margins (tCO2)" if effect == "margins"
	replace effect = "Emissions Averages (tCO2)" if effect == "averages_at_mgswind"
	***************************************************************************
	twoway 	(rcap ci_lb ci_ub wind_5_50, by(effect) color(navy)) || ///
			(line yvalue wind_5_50, by(effect, col(1) yrescale note("") graphregion(color(white))) color(navy)) || ///
			, graphregion(color(white)) ///
			legend(size(*.8) symxsize(*.6) order(1 "Emissions (tCO2)") row(1)) ///
			ytitle("") xtitle("Wind (GWh)",size(small)) ///
			xlabel(#10, labsize(vsmall)) ylabel(,angle(90) labsize(vsmall))
			graph export "$dirpath/figures/Spline_FeHr2_C5_Emissions_Margins_Averages.pdf", as(pdf) replace
	***************************************************************************
	restore


	/***************************************************************************
	   1.4. Averages Graph
	***************************************************************************/ 
	preserve
	keep if yvar == "tcost" & spec == "spline" & fe=="$fe_choice" & controls=="5" & effect != "averages_cond"
	
	sort effect xvalue
	gen yvalue1 = yvalue if (xvalue == 1 & effect == "margins")
	fillmissing yvalue1, with(any)
	gen yvalue2 = yvalue if (xvalue == 2 & effect == "margins")
	fillmissing yvalue2, with(any)
	gen yvalue3 = yvalue if (xvalue == 3 & effect == "margins")
	fillmissing yvalue3, with(any)
	gen yvalue4 = yvalue if (xvalue == 4 & effect == "margins")
	fillmissing yvalue4, with(any)
	gen yvalue5 = yvalue if (xvalue == 5 & effect == "margins")
	fillmissing yvalue5, with(any)
	
	
	*gen med_wind_x_margins = wind_5_50 * yvalue
	gen med_wind_x_margins = yvalue1*windsp1max + yvalue2*windsp2max + yvalue3*windsp3max + yvalue4*windsp4max + yvalue5*windsp5max
	replace effect = "Operational Cost Margins (EUR/MWh)" if effect == "margins"
	replace effect = "Operational Cost Averages (EUR/MWh)" if effect == "averages_at_mgswind"
	***************************************************************************
	twoway 	rcap ci_lb ci_ub wind_5_50, by(effect) color(navy) || ///
			line yvalue wind_5_50, by(effect, col(1) yrescale note("") graphregion(color(white))) color(navy) || ///
			line med_wind_x_margins wind_5_50 if effect == "Operational Cost Averages (EUR/MWh)", color(red) || ///
			line tcost_5 wind_5_50 if effect == "Operational Cost Averages (EUR/MWh)", color(olive_teal) || ///
			, graphregion(color(white)) ///
			legend(size(*.8) symxsize(*.6) order(1 "cost averages and margins" 3 "margins*wind" 4 "mean cost") row(1)) ///
			ytitle() xtitle("Wind (GWh)",size(small)) ///
			xlabel(#10, labsize(vsmall)) ylabel(,angle(90) labsize(vsmall)) 
	graph export "$dirpath/figures/Spline_FeHr2_C5_TCost_Averages_Comparison.pdf", as(pdf) replace
	***************************************************************************
	restore
	
	
/*******************************************************************************

	2. Intermittency Graphs

*******************************************************************************/
	* Merge the median values with the regression results
	use "$dirpath/results/results_VU_regressions.dta", clear
	merge m:1 xvalue using "$dirpath/data/output/wind_5_50.dta", nogen
	
	/***************************************************************************
	   2.1. Uncertainty 
	   
	***************************************************************************/ 
	preserve
	keep if yvar == "tcost" & (spec == "VU_1 spline" | spec == "spline") & fe=="$fe_choice" & controls=="5" & (effect == "averages_unc" | effect == "margins_unc")
	replace effect = "Cost Averages (EUR/MWh)" if effect == "averages_unc"
	replace effect = "Cost Margins (EUR/MWh)" if effect == "margins_unc"
	***************************************************************************
	twoway 	(rcap ci_lb ci_ub wind_5_50 if (unc == "5"), by(effect) color(eltblue)) || ///
			(rcap ci_lb ci_ub wind_5_50 if (unc == "50"), by(effect) color(ebblue)) || ///
			(rcap ci_lb ci_ub wind_5_50 if (unc == "95"), by(effect) color(navy)) || ///
			(line yvalue wind_5_50 if (unc == "95"), by(effect, col(1) yrescale note("") graphregion(color(white))) color(navy)) || ///
			(line yvalue wind_5_50 if (unc == "50"), by(effect) color(ebblue)) || ///
			(line yvalue wind_5_50 if (unc == "5"), by(effect) color(eltblue)) || ///
			, graphregion(fcolor(white)) ///
			legend(size(*.8) symxsize(*.6) order(1 "Unc: 5%" 2 "Unc: 50%" 3 "Unc: 95%") row(1)) ///
			ytitle("") xtitle("Wind (GWh)",size(small)) ///
			xlabel(#10, labsize(vsmall)) ylabel(,angle(90) labsize(vsmall))
			graph export "$dirpath/figures/Unc1_FeSh_C8_Costs_Margins_Averages.pdf", as(pdf) replace
	***************************************************************************
	restore	

	/***************************************************************************
	   2.2. Volatility 
	***************************************************************************/ 
	preserve
	keep if yvar == "tcost" & (spec == "VU_1 spline" | spec == "spline") & fe=="$fe_choice" & controls=="5" & (effect == "averages_vol" | effect == "margins_vol")
	replace effect = "Cost Averages (EUR/MWh)" if effect == "averages_vol"
	replace effect = "Cost Margins (EUR/MWh)" if effect == "margins_vol"
	***************************************************************************
	twoway  (rcap ci_lb ci_ub wind_5_50 if (vol == "5"), by(effect) color(eltblue)) || ///
			(rcap ci_lb ci_ub wind_5_50 if (vol == "50"), by(effect) color(ebblue)) || ///
			(rcap ci_lb ci_ub wind_5_50 if (vol == "95"), by(effect) color(navy)) || ///
			(line yvalue wind_5_50 if (vol == "95"), by(effect, col(1) yrescale note("") graphregion(color(white))) color(navy)) || ///
			(line yvalue wind_5_50 if (vol == "50"), by(effect) color(ebblue)) || ///
			(line yvalue wind_5_50 if (vol == "5"), by(effect) color(eltblue)) || ///
			, graphregion(fcolor(white)) ///
			legend(size(*.8) symxsize(*.6) order(1 "Vol: 5%" 2 "Vol: 50%" 3 "Vol 95%") row(1)) ///
			ytitle("") xtitle("Wind (GWh)",size(small)) ///
			xlabel(#10, labsize(vsmall)) ylabel(,angle(90) labsize(vsmall))
			graph export "$dirpath/figures/Vol1_FeSh_C8_Costs_Margins_Averages.pdf", as(pdf) replace
	***************************************************************************
	restore
	

	/*******************************************************************************

		3. Welfare Graphs

	*******************************************************************************/
	clear all
	set type double
	set more off
	program drop _all
	set maxvar 32767
	
	*! NJC 1.0.0 16 Oct 2003 
	program tabstatmat  
		
		args matout garbage 
		if "`matout'" == "" | "`garbage'" != "" error 198 

		if "`r(name1)'" == "" { 
			di as err "nothing found"
			exit 498
		} 	

		* how many vectors? 
		local I = 1 
		while "`r(name`I')'" != "" { 
			local ++I 
		} 	
		local --I 

		* build up matrix 
		if rowsof(r(Stat1)) == 1 { 
			forval i = 1/`I' { 
				local vectors "`vectors' r(Stat`i') \"
				local names   "`names' `r(name`i')'" 
			} 
			matrix `matout' = `vectors' r(StatTot)
		} 
		else { 
			forval i = 1/`I' { 
				local vectors "`vectors' (r(Stat`i'))' \"
				local names   "`names' `r(name`i')'" 
			} 
			matrix `matout' = `vectors' (r(StatTot))'  
		} 	

		matrix rownames `matout' = `names' Total 
		matrix list `matout'
	end 
	
	/***************************************************************************
	   3.1. SPLINE Welfare Graph
	***************************************************************************/ 
	
	use "$dirpath/results/results_spline_welfare_regressions_NEW.dta", clear
	
	replace yvar = "price0_margin" if yvar=="price0" & effect=="margins"
	replace yvar = "price0_avg" if yvar=="price0" & effect=="average"
	
	keep if fe=="fe_sh" & controls=="5"
	forvalues x = 1(1)5 {
	    preserve
		tempfile spline_`x'
	    keep if xvalue == `x'

		local new = _N + 9
		set obs `new'

		replace yvar = "Total" 	 	if _n==`new'
		replace yvar = "Total_ni" 	if _n==`new'-1
		replace yvar = "Subsidy" 	if _n==`new'-2
		replace yvar = "emissions" 	if _n==`new'-3
		replace yvar = "PS_trad" 	if _n==`new'-4
		replace yvar = "PS_wind_ni" if _n==`new'-5
		replace yvar = "PS_wind" 	if _n==`new'-6
		replace yvar = "CS_ni" 	 	if _n==`new'-7
		replace yvar = "CS" 	 	if _n==`new'-8
	
		local subsidy_cost = 40
	
	
		* Computing PS and Welfare effects
		foreach v in "yvalue" "ci_lb" "ci_ub" {
		
			tabstat `v', by(yvar) stat(mean) save
			tabstatmat f1

			* producer surplus change is lost revenue plus deviation costs minus mg. cost reductions
			local PS_trad = f1[rownumb(f1,"price0_tdemand"),1] + 0.0005 * f1[rownumb(f1,"price0_margin"),1] + f1[rownumb(f1,"price0_avg"),1]

			local PS_wind = f1[rownumb(f1,"price_wind_wdemand"),1] + `subsidy_cost'

			local PS_wind_ni = f1[rownumb(f1,"price0_wdemand"),1] + `subsidy_cost'

			local CS = - f1[rownumb(f1,"finalp_demand"),1] - `subsidy_cost'

			local CS_ni = - f1[rownumb(f1,"price0_demand"),1] - `subsidy_cost'

			local  emis = -100 * f1[rownumb(f1,"emis_2"),1] + f1[rownumb(f1,"emis_1"),1]

			local welfare = `CS' + `PS_trad' + `PS_wind' + `emis'

			local welfare_ni = `CS_ni' + `PS_trad' + `PS_wind_ni' + `emis'


			replace `v' = `PS_trad' if yvar=="PS_trad"
			replace `v' = `PS_wind' if yvar=="PS_wind"
			replace `v' = `PS_wind_ni' if yvar=="PS_wind_ni"
			replace `v' = `CS' 		if yvar == "CS"
			replace `v' = `CS_ni' 	if yvar == "CS_ni"
			replace `v' = `emis' 	if yvar == "emissions"
			replace `v' = `welfare' if yvar=="Total"
			replace `v' = `welfare_ni' if yvar=="Total_ni"
		
		}
		
		replace xvalue = `x'
		save "`spline_`x''", replace
		restore
	}
	clear
	forvalues x = 1(1)5 {
		append using "`spline_`x''"
	}
	fillmissing xvalue, with(previous)
	
	preserve 
		gen id = .
		replace id = 1 if yvar == "CS"
		replace id = 2 if yvar == "PS_trad" 
		replace id = 3 if yvar == "PS_wind" 
		replace id = 4 if yvar == "emissions"
		replace id = 5 if yvar == "Total"
		keep if id != .
		gen test = 7*id + xvalue - 7
		
		***************************************************************************
			twoway (bar yvalue test if (id == 1), color(navy)) ///
				(bar yvalue test if (id == 2), color(dkgreen)) ///
				(bar yvalue test if (id == 3), color(purple)) ///
				(rcap ci_lb ci_ub test if (id ==1 | id ==2 | id==3), color(black)), ///
				xlabel(3 "Consumer Surplus" 10 "Non-Wind Producer Surplus" 17 "Wind Revenue", noticks) ///
				graphregion(color(white)) legend(off) xtitle("") ytitle("EUR/MWh")
				graph export "$dirpath/figures/Welfare_New1.pdf", as(pdf) replace
		***************************************************************************
	restore
	
	preserve 
		gen id = .
		replace id = 1 if yvar == "CS_ni"
		replace id = 2 if yvar == "PS_trad" 
		replace id = 3 if yvar == "PS_wind" 
		replace id = 4 if yvar == "emissions"
		replace id = 5 if yvar == "Total_ni"
		keep if id != .
		gen test = 7*id + xvalue - 7
		
		***************************************************************************
			twoway (bar yvalue test if (id == 1), color(navy)) ///
				(bar yvalue test if (id == 2), color(dkgreen)) ///
				(bar yvalue test if (id == 3), color(purple)) ///
				(rcap ci_lb ci_ub test if (id ==1 | id ==2 | id==3), color(black)), ///
				xlabel(3 "Consumer Surplus" 10 "Non-Wind Producer Surplus" 17 "Wind Revenue", noticks) ///
				graphregion(color(white)) legend(off) xtitle("") ytitle("EUR/MWh")
				graph export "$dirpath/figures/Welfare_New1_NOINT.pdf", as(pdf) replace
		***************************************************************************
	restore	
	
	
	/***************************************************************************
	   3.2. Linear LCOE SCC Sensitivity Welfare Graph
	***************************************************************************/ 			
	use "$dirpath/results/results_linear_welfare_regressions_NEW.dta", clear
	
	replace yvar = "price0_margin" if yvar=="price0" & effect=="margins"
	replace yvar = "price0_avg" if yvar=="price0" & effect=="average"
	
	keep if fe=="$fe_shift" & controls=="5"
	gen id = .
	
	forvalues x = 50(20)90 {
		forvalues y = 30(5)150 {
		preserve
		tempfile lin_`x'`y'
		local new = _N + 6
		set obs `new'
	
		replace yvar = "PS_trad" if _n==`new'-2
		replace yvar = "Subsidy" if _n==`new'-1
		replace yvar = "Total" if _n==`new'
		replace yvar = "CS" if _n ==`new' - 3
		replace yvar = "PS_wind" if _n==`new'-4
		replace yvar = "emissions" if _n==`new'-5
	
		local subsidy_cost = 40
		
		* Computing PS and Welfare effects
		foreach v in "yvalue" "ci_lb" "ci_ub" {
		
			tabstat `v', by(yvar) save
			tabstatmat f1

			* producer surplus change is lost revenue plus deviation costs minus mg. cost reductions
			local PS_trad = f1[rownumb(f1,"price0_tdemand"),1] + 0.0005 * f1[rownumb(f1,"price0_margin"),1] + f1[rownumb(f1,"price0_avg"),1]
				
			local PS_wind = f1[rownumb(f1,"price_wind_wdemand"),1] + `subsidy_cost' - `x'
			
			local CS = - f1[rownumb(f1,"finalp_demand"),1] - `subsidy_cost'
			
			local  emis = -`y' * f1[rownumb(f1,"emis_2"),1] + f1[rownumb(f1,"emis_1"),1]
				
			local welfare = `CS' + `PS_trad' + `PS_wind' + `emis'
		
			replace `v' = `PS_trad' if yvar=="PS_trad"
			replace `v' = `PS_wind' if yvar=="PS_wind"
			replace `v' = `welfare' if yvar=="Total"
			replace `v' = `CS' if yvar == "CS"
			replace `v' = `emis' if yvar == "emissions"
		}
		gen cost = `x'
		gen emi = `y'
		replace id = 1 if yvar == "CS"
		replace id = 2 if yvar == "PS_trad" 
		replace id = 3 if yvar == "PS_wind" 
		replace id = 4 if yvar == "emissions"
		replace id = 5 if yvar == "Total"
		save "`lin_`x'`y''", replace
		restore
		}
	}
	keep if id == 6
	forvalues x = 50(20)90 {
		forvalues y = 30(5)150 {
			append using "`lin_`x'`y''"
		}
	}
	gen zero = 0
	
	***************************************************************************
	twoway (line yvalue emi if (id == 5 & cost == 50), color(navy) lwidth(medthick)) ///
			(line yvalue emi if (id == 5 & cost == 70), color(blue) lwidth(medthick)) ///
			(line yvalue emi if (id == 5 & cost == 90), color(eltblue) lwidth(medthick)) ///
			(line zero emi if (id == 5 & cost == 90), color(black) lwidth(thin)) ///
			, graphregion(color(white)) xlabel(30 50 70 90 110 130 150) ///
			legend(size(*.8) symxsize(*.6) order(1 "LCOE = 50" 2 "LCOE = 70" 3 "LCOE = 90") row(1) position(6)) /// 
			xtitle("Social Cost of Carbon (EUR/tCO2)") ytitle("Total Welfare (EUR/MWh)")
			graph export "$dirpath/figures/Welfare_New2.pdf", as(pdf) replace
    ***************************************************************************
	
