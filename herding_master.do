* Do-file for Herding in Bank Lending: An Analysis of Indian Banking Sector
* Shihas Abdul Razak


*** Initialization ***

version 14.2
cap log close
clear all
set more off , permanently
set varabbrev off

*set your path to the root folder here by copy-editing the following code

if "`c(username)'" == "Shihas Abdul Razak" global root "C:\Users\Shihas Abdul Razak\Dropbox\Research/Herding"
if "`c(username)'" == "DELL" global root "C:\Users\DELL\Dropbox\Research\Herding"

*this code will show the username
di "`c(username)'"

cd "${root}"

{/*** Data wrangling ***/

*************
*** OSMOS ***
*************

* Set convenient globals
global osmos_raw "$root/data/raw/OSMOS"
global osmos_clean "$root/data/derived/OSMOS"

* Create required folders
cap mkdir "$root/data/derived"
cap mkdir "$root/data/derived/OSMOS"

{/*** OSMOS Data, 18 sectors (including pre_2015 data) ***/

import excel "$osmos_raw/OSMOS_Data_25-4-2019_edit.xlsx", sheet("Sheet1") firstrow clear

*Segregating item description into different variables
gen item = substr( ItemDescription , strrpos( ItemDescription , "-" )+ 2, .)
split ItemDescription , parse(" - " "-" "Advances Outstanding" "GNPAs" "Gross NPAs" "Gross Advances")
gen sector = ItemDescription1 + " " + ItemDescription2 + " " + ItemDescription3 + " " + ItemDescription4 + " " + ItemDescription5
replace sector = strrtrim(sector)
drop ItemDescription*

*deleting repeating observations
drop if item=="Gross Advances" | item=="Gross NPAs"

*making the item variable uniform and removing the spaces to change it into variable name
replace item = "GNPAs" if item == "NPAs"
replace item = subinstr(item, " ", "", .)

rename BankNameBankGroupWise BankName
rename BankGroupLevel2 BankGroup

*dropping Foreign and other banks, also group observations
drop if BankGroup!="Private Sector Banks" & BankGroup!="Public Sector Banks"
drop if BankName==" Private Sector Banks" | BankName==" Public Sector Banks"

*reshaping
capture reshape long V, i(BankName sector item) j(Exceldate)
reshape error //some data for IDBI Bank is repeating as PVB 
drop if BankName=="IDBI BANK LIMITED" & BankGroup=="Private Sector Banks"
reshape long V, i(BankName sector item) j(Exceldate)

*generating date from excel date
gen date = Exceldate + td(30dec1899)
format date %td
drop Exceldate
gen qtr=qofd(date)

*reshaping
reshape wide V, i( BankName sector qtr) j(item) string
rename *V* **

*dropping observations before Q3 2012, there is only data for priority agriculture and retail services
drop if qtr<210

save "$osmos_clean/OSMOS1.dta", replace

}


{/*** OSMOS Data, 28 sectors (only post-2015 data) ***/

import excel "$osmos_raw/Sectoral Distribution of Credit_Data_OSMOS_26-12-19_edit1.xlsx", sheet("Sheet 1") firstrow clear

*dropping unwanted variables
drop NetProfitLossPAT TotalAssets CapitalRatioCRARStandalone ReturnonTotalAssetsannualiz

*Segregating item description into different variables
gen item = substr( ItemDescription , strrpos( ItemDescription , "-" )+ 2, .)
split ItemDescription , parse(" - " "-" "Advances Outstanding" "GNPAs" "Gross NPAs" "Gross Advances")
gen sector = ItemDescription1 + " " + ItemDescription2 + " " + ItemDescription3 + " " + ItemDescription4 + " " + ItemDescription5
replace sector = strrtrim(sector)
drop ItemDescription*

*making the item variable uniform and removing the spaces to change it into variable name
replace item = "GNPAs" if item == "Gross NPAs"
replace item = "Advances Outstanding" if item == "Gross Advances"
replace item = subinstr(item, " ", "", .)

rename BankBankGroupName BankName

*cleaning date variable
generate date = dofc( ReportingDate )
format date %td
gen qtr=qofd( date )
drop ReportingDate

*reshaping
reshape wide value, i( BankName sector qtr) j(item) string
rename *value* **

save "$osmos_clean/OSMOS2.dta", replace

}

{/*** Compiling both data ***/

use "$osmos_clean/OSMOS2.dta", clear

*dropping non-public & non-private banks
merge m:m BankName using "$osmos_clean\OSMOS1.dta", keep(match) nogen
keep BankName BankGroup
duplicates drop BankName, force
merge m:m BankName using "$osmos_clean\OSMOS2.dta", keep(match) nogen

*compiling
append using "$osmos_clean\OSMOS1.dta"

*dropping duplicates
duplicates drop BankName sector qtr, force

*dropping Priority lending
drop if sector== "Priority Agriculture and Allied Activities"

save "$osmos_clean/OSMOS_compiled.dta", replace
}


*************************
*** Economic Activity ***
*************************

* Create required folders
cap mkdir "$root/data/derived/Economic Activity"

* Set convenient globals
global eco_raw "$root/data/raw/Economic Activity"
global eco_clean "$root/data/derived/Economic Activity"

{/*** GVA ***/

import excel "$eco_raw\HBS_Table_No._158___Quarterly_Estimates_of_Gross_Domestic_Product_at_Factor_Cost_(at_Current_Prices)_(New_Series)_(Base__2004-05)_reshaped.xlsx", sheet("Sheet 1") firstrow

*cleaning date variable
rename Date ReportingDate
generate date = dofc( ReportingDate )
format date %td
gen qtr=qofd( date )
drop ReportingDate date

save "$eco_clean\gva.dta", replace
}

{/*** PFCE ***/

import excel "$eco_raw\HBS_Table_No._03___Components_of_Gross_Domestic_Product_(at_Factor_Cost).xlsx", sheet("Sheet1") firstrow clear

*extending to quarters
gen year = yofd(Date)
expand 4
bysort year : gen qtr = yq(year, _n)
destring eco_act, replace
replace eco_act = eco_act/4 // flow variable
replace qtr = qtr - 3 // adjusting for fiscal year since we did create this with normal year
drop year Date

save "$eco_clean/pfce.dta", replace
}

{/*** Compiling and Matching sectors ***/

*dta file of sector matches
import excel "$eco_raw\Matching sector.xlsx", sheet("Sheet1") firstrow clear
save "$eco_clean/Matching sector.dta", replace

*compiling gva and pfce
use "$eco_clean\gva.dta", clear
append using "$eco_clean\pfce.dta"
save "$eco_clean/gva + pfce.dta", replace

}


*****************
*** Compiling ***
*****************

*matching sectors with OSMOS data
use "$root\data\derived\OSMOS\OSMOS_compiled.dta", clear
merge m:m sector using "$root\data\derived\Economic Activity\Matching sector.dta", nogen

*adding eco_activity data
merge m:m sector_eco qtr using "$root\data\derived\Economic Activity\gva + pfce.dta", keep(master match) nogen

*labeling variables
label var AdvancesOutstanding "Advances Outstanding"
label var GNPAs "GNPA"
label var eco_act "Economic Activity Indicator"
label var sector_eco "Matched sector for economic activity"
label var qtr "Quarter no. Stata"
label var BankGroup "Bank Type"
label var BankName "Bank Name"
label var sector "Sector"
label var date "Date"

save "$root/data/derived/master_herding.dta", replace

***********************
*** Bank Financials ***
***********************

* Create required folders
cap mkdir "$root/data/derived/Bank Financials"

* Set convenient globals
global bank_raw "$root/data/raw/Bank Financials"
global bank_clean "$root/data/derived/Bank Financials"


{/*** ROA and TA Data for latest quarters ***/

import excel "$osmos_raw/Sectoral Distribution of Credit_Data_OSMOS_26-12-19_edit1.xlsx", sheet("Sheet 1") firstrow clear

keep BankBankGroupName ReportingDate TotalAssets ReturnonTotalAssetsannualiz

*cleaning date variable
generate Date = dofc( ReportingDate )
format Date %td
gen qtr = qofd( Date )
drop *Date*

rename BankBankGroupName BankName
rename ReturnonTotalAssetsannualiz ROA

duplicates drop BankName qtr, force

save "$bank_clean/ROA and TA 15-19.dta", replace
}

{/*** ROA and TA Data for whole sample***/
import excel "$bank_raw\Bank_financials.xlsx", sheet("Sheet1") firstrow clear

drop if BankType != "PRIVATE SECTOR BANKS" & BankType != "PUBLIC SECTOR BANKS"
keep BankName Date ROA TotalAssets

*cleaning date variable
gen ReportingDate = date(Date, "MDY")
format ReportingDate %td
gen qtr=qofd( ReportingDate )
drop *Date*

drop if qtr<210

*merging ROA and TA data for latest period
gen identifier=1 // since other data has non-private and non-public banks
merge m:m BankName qtr using "$bank_clean\ROA and TA 15-19.dta"

*dropping other banks
bys BankName: egen identifier1 = min(identifier)
sort BankName qtr
drop if identifier1!=1
drop identifier _merge identifier1

sort BankName qtr
save "$bank_clean/ROA and TA - Full sample.dta", replace
}

{/*** Finding top and profitable banks ***/

use "$bank_clean/ROA and TA - Full sample.dta", clear

*finding top banks in terms of size
preserve

bys BankName: egen size = mean( TotalAssets)
duplicates drop BankName size, force
sort size
/*  Top 2 Banks - STATE BANK OF INDIA HDFC BANK LTD.
	Top 5 Banks - STATE BANK OF INDIA HDFC BANK LTD. ICICI BANK LIMITED PUNJAB NATIONAL BANK CANARA BANK
	Top 3 Pvt. Banks - HDFC BANK LTD. ICICI BANK LIMITED AXIS BANK LIMITED */

restore

*capturing threshold values for size and ROA
putexcel set "$bank_clean/Threshold values", replace

*ROA p50
quietly putexcel A1=("qtr") B1=("ROA_p50")
tabstat ROA , by( qtr )  statistics(p50) save
forvalues i = 210/238 {
		local x = `i' - 209
		mat A`x' = r(Stat`x')
		local row = `x'+ 1
		qui putexcel A`row'=(`i') B`row'=A`x'[1,1]
		sleep 500
	}

*ROA p75
quietly putexcel C1=("ROA_p75")
tabstat ROA , by( qtr )  statistics(p75) save
forvalues i = 210/238 {
		local x = `i' - 209
		mat A`x' = r(Stat`x')
		local row = `x'+ 1
		qui putexcel C`row'=A`x'[1,1]
		sleep 500
	}

*Total Assets p50
quietly putexcel D1=("size")
tabstat TotalAssets , by( qtr )  statistics(median) save
forvalues i = 210/238 {
		local x = `i' - 209
		mat A`x' = r(Stat`x')
		local row = `x'+ 1
		qui putexcel D`row'=A`x'[1,1]
		sleep 500
	}

*generating merge file for big and profitable banks
preserve

import excel "$bank_clean\Threshold values.xlsx", sheet("Sheet1") firstrow clear
save "$bank_clean\Threshold values.dta"

restore

merge m:m qtr using "$bank_clean\Threshold values.dta", nogen

foreach i in 50 75{
		gen big_prof_`i' = 0
		replace big_prof_`i' = 1 if ROA >= ROA_p`i' & TotalAssets >= size
	}

keep BankName qtr big_prof_50 big_prof_75

save "$bank_clean/big and prof banks.dta", replace

}


****************************
*** Generating Variables ***
****************************

{/*** Generating Different files for Advances Outstanding of different groups ***/

use "$root/data/derived/master_herding.dta", clear

*Big5 and Big2
preserve

keep if BankName == "STATE BANK OF INDIA" | BankName == "HDFC BANK LTD." | BankName == "ICICI BANK LIMITED" | BankName == "PUNJAB NATIONAL BANK" | BankName == "CANARA BANK"
bys sector qtr: egen AO_big5=total (AdvancesOutstanding)
keep if BankName == "STATE BANK OF INDIA" | BankName == "HDFC BANK LTD." 
bys sector qtr: egen AO_big2=total (AdvancesOutstanding)
duplicates drop ( sector qtr ), force
keep sector qtr AO_big5 AO_big2
save "$root\data\derived/AO Big Banks.dta",replace

restore

*Big Private
preserve

keep if BankName == "HDFC BANK LTD." | BankName == "ICICI BANK LIMITED" | BankName == "AXIS BANK LIMITED"
bys sector qtr: egen AO_pvt_big= total (AdvancesOutstanding)
duplicates drop ( sector qtr ), force
keep sector qtr AO_pvt_big
save "$root\data\derived/AO Pvt Big.dta",replace

restore

*Big Profitable
foreach i in 50 75{

preserve

merge m:m BankName qtr using "$root\data\derived\Bank Financials\big and prof banks.dta", nogen
keep if big_prof_`i' == 1
bys sector qtr: egen AO_prof`i'= total (AdvancesOutstanding)
duplicates drop ( sector qtr ), force
keep sector qtr AO_prof`i'

save "$root\data\derived/AO Prof `i'.dta",replace

restore
}

* Creating Bank ID
preserve

keep BankName
encode BankName , gen(bank_id) label(id)
label values bank_id
tostring bank_id, replace
replace bank_id = "B" + bank_id

save "$root\data\derived\bank_id.dta", replace

restore

* Wide Advances Outstanding for each bank
merge m:m BankName using "$root\data\derived\bank_id.dta", nogen

preserve

keep sector qtr AdvancesOutstanding bank_id
rename AdvancesOutstanding AO_

reshape wide AO_, i(sector qtr) j( bank_id) string

save "$root\data\derived\wide Advances Outstanding without adjustment.dta", replace

restore

preserve

merge m:m sector qtr using "$root\data\derived\wide Advances Outstanding without adjustment.dta", nogen

forvalues i = 1/61{
		replace AO_B`i' = . if bank_id == "B`i'"
		label var AO_B`i' "B`i' Advances Outstanding"
	}

save "$root\data\derived\wide Advances Outstanding.dta", replace


restore

}

{/*** Merging and Generating Other variables ***/

use "$root/data/derived/master_herding.dta", clear

*merging other files
local files `" "AO Big Banks" "AO Pvt Big" "AO Prof 50" "AO Prof 75" "'
foreach filename of local files{
		merge m:m sector qtr using "$root\data\derived/`filename'.dta", nogen
	}

merge m:m sector qtr BankName using "$root\data\derived/wide Advances Outstanding.dta", nogen

** All others Adv Outstanding
bys sector qtr: egen AO_all= total (AdvancesOutstanding)
gen AO_O= AO_all- AdvancesOutstanding

*GNPA at sector level
bys sector qtr: egen GNPA_sector = total(GNPAs)

label var AO_big5 "Advances Outstanding - Big 5"
label var AO_big2 "Advances Outstanding - Big 2"
label var AO_pvt_big "Advances Outstanding - Pvt. Big 3"
label var AO_prof50 "Advances Outstanding - Big Prof(50th percentile ROA)"
label var AO_prof75 "Advances Outstanding - Big Prof(75th percentile ROA)"
label var AO_all "Total Advances to the sector"
label var AO_O "All others' Advances Outstanding"
label var bank_id "Bank ID"
label var GNPA_sector "Sectoral GNPA"

*taking logs
local varlist "  AdvancesOutstanding GNPAs eco_act AO_big5 AO_big2 AO_pvt_big AO_prof50 AO_prof75 AO_all AO_O GNPA_sector "

foreach var of local varlist{
		gen `var'_1 = 1 + `var'
		gen log_`var' = ln(`var'_1)
		drop `var'_1
		local label : var label `var'
		label var log_`var' "Log of `label'"
	}

forvalues i = 1/61{
		gen AO_B`i'_1 = 1 + AO_B`i'
		gen log_AO_B`i' = ln(AO_B`i'_1)
		drop AO_B`i'_1
		local label : var label AO_B`i'
		label var log_AO_B`i' "Log of `label'"
	}

*yoy growth of eco_activity
sort BankName sector qtr
bys BankName sector: gen eco_act_growth = log_eco_act - log_eco_act[_n-4]
label var eco_act_growth "Y-O-Y growth of Economic Activity"

encode BankName, gen(bank)

/*** Filters ***/

egen groupid = group ( BankName sector )

bys groupid  : ipolate log_AdvancesOutstanding qtr, generate (log_AO_ipolated) //filtering needs gapless series
label var log_AO_ipolated "Ipolated series log Advances Outstanding"

xtset groupid qtr

*HP filter
tsfilter hp AO_cycle_hp = log_AO_ipolated, trend(AO_trend_hp)

label var AO_cycle_hp "AO Cyclical Component - HP filter"
label var AO_trend_hp "AO Trend Component - HP filter"

*BK filter
tsfilter bk AO_cycle_bk = log_AO_ipolated, trend(AO_trend_bk) smaorder(6)
label var AO_cycle_bk "AO Cyclical Component - BK filter"
label var AO_trend_bk "AO Trend Component - BK filter"

*Hamilton filter



************************
*** Defining Program ***
************************

* There was a bug in the hamiltonfilter command. Following codes are copy-edited from hamiltonfilter.ado written by Diallo Ibrahima Amadou
* Update - The ssc command has been updated after informing the author.

capture program drop hamiltonfilter_sar
program hamiltonfilter_sar
	syntax varname(numeric ts), STUB(string)
	marksample touse
	local panelvar "`r(panelvar)'"
	local timevar  "`r(timevar)'"

	tsset
	tempvar ydepvarb
	qui generate double `ydepvarb' = `varlist' if `touse'
	qui confirm new var `stub'_trend_hamilton
	qui confirm new var `stub'_cycle_hamilton

	
					generate double `stub'_trend_hamilton  = . if `touse'
					label var `stub'_trend_hamilton "`stub' Trend Component - Hamilton Filter"
					generate double `stub'_cycle_hamilton  = . if `touse'
					label var `stub'_cycle_hamilton "`stub' Cyclical Component - Hamilton Filter"
					local nbpays = `panelvar'[_N]	
					confirm new var `stub'_trendprov
					confirm new var `stub'_cycleprov
					forvalues i = 1/`nbpays' {
												capture {
														 regress `ydepvarb' L(8/11).`ydepvarb' if `touse' & `panelvar' == `i'
														 predict double `stub'_trendprov if `touse' & `panelvar' == `i', xb
														 predict double `stub'_cycleprov if `touse' & `panelvar' == `i', residuals
														 replace `stub'_trend_hamilton = `stub'_trendprov if `touse' & `panelvar' == `i'
														 replace `stub'_cycle_hamilton = `stub'_cycleprov if `touse' & `panelvar' == `i'
														 drop `stub'_trendprov `stub'_cycleprov
											  		    }
											 }
end


xtset groupid qtr

hamiltonfilter_sar log_AO_ipolated, stub(AO)

save "$root\data\derived\herding_analyses.dta", replace

}


{/*** Analyses ***/

use "$root\data\derived\herding_analyses.dta", clear

log using "$root/scratch/overall_reg.txt", text replace

***************
*** Overall ***
***************

xtset groupid qtr

local varlist " log_AO_all log_AO_big5 log_AO_big2 log_AO_pvt_big log_AO_prof50 log_AO_prof75 "

foreach var of local varlist{
qui xtreg AO_cycle_hp L.`var' L.D.`var' L.D.log_GNPAs L.log_eco_act, fe
eststo M1
qui xtreg AO_cycle_hp L.`var' L.D.log_GNPAs L.log_eco_act, fe
eststo M2
qui xtreg AO_cycle_hp L.D.`var' L.D.log_GNPAs L.log_eco_act, fe
eststo M3

local label : var label `var'

*esttab M1 M2 M3 using "$root/scratch/results_cyc_`var'.txt", title("Cyclical Component against `label'") star(* .1 ** .05 *** .01) label replace
esttab M1 M2 M3 , title("Cyclical Component against `label'") star(* .1 ** .05 *** .01) label 

qui xtreg D.AO_trend_hp L.`var' L.D.`var' L.D.log_GNPAs L.log_eco_act, fe
eststo M4
qui xtreg D.AO_trend_hp L.`var' L.D.log_GNPAs L.log_eco_act, fe
eststo M5
qui xtreg D.AO_trend_hp L.D.`var' L.D.log_GNPAs L.log_eco_act, fe
eststo M6

*esttab M4 M5 M6 using "$root/scratch/results_trnd_`var'.txt", title("Growth in Trend Component against `label'") star(* .1 ** .05 *** .01) label replace
esttab M4 M5 M6, title("Growth in Trend Component against `label'") star(* .1 ** .05 *** .01) label 


}

log close

log using "$root/scratch/sector-wise regressions.txt", text replace

*********************
*** Sector - wise ***
*********************

qui levelsof sector, local(sectors)

foreach sect of local sectors{
	preserve
	keep if sector == "`sect'"
			forvalues i = 1/61{
				qui mdesc log_AO_B`i'
				if `r(percent)' > 50 {
										cap qui drop log_AO_B`i'
										}
			}
	
	xtset bank qtr
	
	cap qui xtreg AO_cycle_hp D.log_AO_B* D.log_GNPAs log_eco_act, fe
	eststo M1
	cap qui xtreg D.AO_trend_hp D.log_AO_B* D.log_GNPAs log_eco_act, fe
	eststo M2
	
	esttab M1 M2, title("`sect'") star(* .1 ** .05 *** .01) mlabels("Cyclical Comp." "D.Trend Component")
	
	restore
}

log close

}
