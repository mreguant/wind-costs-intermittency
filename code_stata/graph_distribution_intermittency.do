********************************************************************************
* GRAPH distribution of Intermittency for different definitions
********************************************************************************

clear
clear matrix
set more off
set matsize 2000

* Read Data *

use "$dirpath/data/output/data_costs_intermittency.dta", clear


egen time = group(year month day hour)
tsset time


* How volatile? Distribution of output in relative terms (divided by actual demand)
preserve
keep vol*
twoway (kdensity vol6  , color(none) lcolor(ebblue) ) ///
	   (kdensity vol12 , color(none) lcolor(emidblue) ) ///
	   (kdensity vol24 , color(none) lcolor(navy) ) , ///
	   legend(row(1) size(*.8) symxsize(*.6) lab(1 "6 hours") lab(2 "12 hours") lab(3 "24 hours"))  ///
	   graphregion(color(white)) ytitle("Frequency", size(small)) ///
	   xtitle("Wind SD Change (GWh)", size(small)) ///
	   xlabel(#5, labsize(small)) 
graph export "$dirpath/figures/graph_distribution_volatility.pdf", as(pdf) replace
restore


* How uncertain? Distribution of output in relative terms (divided by actual demand)
preserve
keep unc*
range atx 0 1.5
foreach v in "unc36" "unc24" "unc12" "unc6" {
	kdensity `v', gen(xp`v' d`v') at(atx) nograph 
}
twoway (line dunc36 xpunc36 , color(none) lcolor(midblue) ) ///
	   (line dunc24 xpunc24  , color(none) lcolor(ebblue) ) ///
	   (line dunc12 xpunc12  , color(none) lcolor(eltblue) ) ///
	   (line dunc6 xpunc6   , color(none) lcolor(ltblue) ), ///
	   legend(row(1) size(*.8) symxsize(*.6) lab(1 "36 hours") lab(2 "24 hours") lab(3 "12 hours") lab(4 "6 hours"))  ///
	   graphregion(color(white)) ytitle("Frequency", size(small)) ///
	   xtitle("SD between Forecast and Wind Delivered (GWh)", size(small)) ///
	   xlabel(0(.2)1) ylabel(#5, labsize(small))  xscale(range(0 1))
graph export "$dirpath/figures/graph_distribution_uncertainty.pdf", as(pdf) replace
restore

