/*******************************************************************************

	Name: master_run_code.do
	
	Goal: Master code to obtain results for 
			"The External and Internal Costs of Wind Intermittency"
	
	Author: Mar Reguant and Lola Segura

*******************************************************************************/

	clear all
	set type double
	set more off
	program drop _all
	set scheme s2color
	
	* set maxvar 32767

/*******************************************************************************

	0. Preface

*******************************************************************************/

	* Run set-up code

	* Globals with years and month 
	
	global startYear = 2009
	global endYear = 2018
	global startMonth = 1
	global endMonth = 12
	
	* Path
	if  "`c(username)'" == "mreguant" {
		global dirpath =  "/Users/mreguant/Documents/git/wind-costs-intermittency"
		global temppath = "/Users/mreguant/temp"
		global codepath = "/Users/mreguant/Documents/git/wind-costs-intermittency"
		global temp "/Users/mreguant/Documents/Temp"
	}

	if  "`c(username)'" == "peter" {
		global dirpath = "C:/Users/peter/OneDrive/Documents/GitHub/wind-costs-intermittency"
		global codepath = "C:/Users/peter/OneDrive/Documents/GitHub/wind-costs-intermittency"
		global temp "C:/Users/peter/OneDrive/Desktop"
	}
	
	cap mkdir  "$dirpath/data/output"
	cap mkdir "$dirpath/tables"
	cap mkdir  "$dirpath/figures"
	cap mkdir  "$dirpath/results"
	global tablepath "$dirpath/tables"
	global figurepath "$dirpath/figures"

	
/*******************************************************************************

	1. Prepare data for analyses

*******************************************************************************/

	* Main dataset
	
	qui do "$codepath/code_stata/create_intermittency.do"

/*******************************************************************************

	2. Motivation and Summary Statistics

*******************************************************************************/


	* Table summary statistics
	
	do "$codepath/code_stata/table_summary_statistics.do"
	
	* Distribution of wind intermittency
	
	do "$codepath/code_stata/graph_distribution_intermittency.do"


/*******************************************************************************

	3. Running Regressions

*******************************************************************************/

	* Basic regressions
	
	do "$codepath/code_stata/analysis_regressions.do"
	
	* Regressions with intermittency
	
	do "$codepath/code_stata/analysis_regressions_VU.do"

	
/*******************************************************************************

	4. Producing outputs

*******************************************************************************/

	* Tables
	
	do "$codepath/code_stata/analysis_tables.do"
	
	* Graphs
	
	do "$codepath/code_stata/analysis_graphs.do"	
	
	
*** END OF FILE ***
	
	
