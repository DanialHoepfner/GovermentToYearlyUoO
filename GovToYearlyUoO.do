********************************************************************************
********************************************************************************
********************************************************************************
*****************Converting Government Level Data to Yearly*********************
*Can be used for any distinct time period with irregular start and stop points**
***************************Written in STATA 14**********************************
********************************************************************************
********************************************************************************

cd "YOUR CURRENT DIRECTORY GOES HERE"
use "GovernmentUoO", clear // UoO means Unit of Observation, Add 13 or Old if using STATA 13 or 11/12
gen year=year(date_in)
gen month=month(date_in)

bysort country year month: gen n=_n //Checking for any time that a government lasts less than a month
tab n //Yes once
list country year month date_in n if n>1|n[_n+1]>1 //Belgium in 1946
drop if _n==26 //Was only in power for two weeks, can drop.
*(could use same procedure, but using days if more precise time periods are needed)
drop n //don't need n anymore


gen time=ym(year, month) //getting a monthly time variable which will later be compressed to yearly
format time %tm //format for readability

xtset country time //Time Set monthly data
tsfill //Adds observations for missing time periods
drop month year //These are no longer correct, they are the year and month government ended
*Were used to affix each government to the correct starting point but
*will be constant across months in next steps which is wrong

/***Since data consistent within governments and not thought to vary dynamically,
it is better to carry forward observations until new government
If linear approximation is more appropriate, for time varying variables there is an 
easy interpol command from STATA*/

foreach i in cabinetID date_in date_out election_date n_parties cabvol {
replace `i'=`i'[_n-1] if `i'==. //For each variable replaces current observation with previous if missing
}
/*Since the data are sorted by country and date, and since STATA starts at the top
of the dataset and moves down the above code works*/

gen date=dofm(time) //Using month and year functions requires date format, not month/year
format date %td //Format for readability
gen month=month(date) 
gen year=year(date) // extracts actual month and year for each observation

bysort year cabinetID: egen mxm=max(month) //Captures the latest month that cabinet was in government that year
bysort year cabinetID: egen mnm=min(month) //Captures the earliest month that cabinet was in government that year
gen monthsin=mxm-mnm //Number of months that cabinet was in office that year
tab monthsin /* Looks correct, many more observations at 11, because governments are
often in governemnt for whole years, runs from 0-11 because December(12)-January(1)=11*/


levelsof(country), local(ccode) //grabbing each country code for command
foreach i of local ccode { //For each country
	forvalues j=1944/1960{ //For each year (Only partial set of years to save time)
		qui sum monthsin if country==`i'&year==`j'
		if r(sd)!=0&r(sd)!=. {
			di r(sd) //There is variation within country years, as it should be
		} //Everything looks good.
	}
}

gen longest=0
levelsof(country), local(ccode) //grabbing each country code
foreach i of local ccode { //for each country
	forvalues j=1944/2010{ //for each year
		qui sum monthsin if country==`i'&year==`j'
		qui recode longest (0=1) if monthsin==r(max)&country==`i'&year==`j'
	} //Keeps the observation if the government is the one with the most months in office that year
di "Country `i' Done"
}
keep if longest==1 //Drops goverments for years in which they aren't in office for the longest

levelsof(country), local(ccode)
foreach i of local ccode { // for each country
	forvalues j=1944/2010{ //for each year
		qui sum monthsin if country==`i'&year==`j'
		if r(sd)!=0&r(sd)!=. {
			di r(sd) //Now there is no variation in months in office per country and year
		} //This means that there is only 1 government per year, as wanted
	}
}

bysort country year: gen n=_n //Counter, number of times government is repeated in each country year

keep if n==1 //We only want 1 observation per country-year
drop month mxm monthsin longest n mnm time date //Don't need these anymore
label variable year "Year"
xtset country year

xtreg cabvol l.cabvol n_parties i.country /*Of course this model doesn't make sense
why transform form government to year and use a government level dv, but just to show it works

Data ready to be merged with yearly data*/
save "YearlyUoO" //yearly unit of observation
