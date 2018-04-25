#! /bin/env tclsh
# Fit the RGS spectrum found in the folder with the input model + power background and retrieves the C-stat value. After that performs a gaussian line search through the whole energy bandwidth with three different velocity dispersion for the lines. Writes the deltac values vs energy in cstatlinescan_$deltav.dat
# input parameters are: the position in keV of the line, the null hypothesis model and the parameters of this one
# author Andres Gurpide Lasheras email: andres.gurpide@gmail.com




###########################
####### parameters ########

set plotdata 0; #boolean to decide whether to plot every fit or not
set c 299792.458; #speed of light in km/s
#gaussian line scan parameters
set energymax 1.5
set energymin 0.5
set deltaE 0.001

#velocity dispersions to broaden the lines according to their energy in km/s
set velocitydispersions {0 500 1000}

#-------------------------------------------------------------------------

# Set fitting method to migrad
method leven

statistic cstat

parallel error 4
parallel leven 4

# Return TCL results for XSPEC commands.
set xs_return_result 1

# source procedures
source $::env(HOME)/scripts/bayesian_scripts/fit_procedures.tcl
source $::env(HOME)/scripts/bayesian_scripts/RGS/cstatlinescan_procedures.tcl

#read arguments
#--------------------
set modelname ""
set params ""

for {set j 0} {$j<$argc} {incr j} {

switch -glob -- [lindex $argv $j] {
-m* {incr j;set modelname [lindex $argv $j]}
-p* {incr j;set params [lindex $argv $j]}
-* {puts "$TAG Error unknown option [lindex $argv $j] [lindex $argv [expr $j +1]] \n Usage: $argv0 -m <model> -p <param1&param2...> "; exit}
}
}

# Keep going until fit converges.
query yes

#load and fit the spectra and background
set modelname [loadandfit $modelname $params]
 
if {$plotdata} {
	# Define plotting details
	setplot energy;setplot add
	#open window
	cpd /xw
	#rebin for plotting purposes
	setpl reb 5 10;pl ld rat
}

#store value of c stat
tclout stat
scan $xspec_tclout "%e" cstatnullmodel

################################
#add line to the model and save cstat value for each energy line
################################
set modelwithline [regsub -all {\)} $modelname {+gaussian)}]

#set model with line (line position, width, norm) freezing line parameters at 0 for the background model
editmo "$modelwithline & 0.5 -1 & 0.0 -1 & 0.0 -1& 0 -1 & 0 -1 & 0 -1"
puts "Modifying model to add the line"

#get number of parameters of the model
tclout modpar
scan $xspec_tclout "%i" nparams
set firstparambackground [expr $nparams/2+1]

#get indexes of the line
set energyparamindex [expr $firstparambackground-5]
set sigmaindex  [expr $firstparambackground-4]
set gaussnormindex [expr $firstparambackground-3]

show parameters 

#variable to store any errors during the process
set outputlog ""

#total time
set totaltime 0
 
#iterate over each velocity dispersion
foreach deltav $velocitydispersions {

#write file header
set outputtext ""
	for {set e $energymin} {$e<$energymax} {set e [expr $e+$deltaE]} {
	 	set energyformat [format "%.3f" $e]
		puts "\n Testing with line at  $energyformat and velocity dispersion $deltav"
		set TIME_start_fit [clock clicks -milliseconds]
#compute width of the line in sigma with new velocity dispersion (Full width hall maximum (Doppler broadening))
		set FWHM [expr 2.0*$e*$deltav/$c]
		set sigma [expr $FWHM/2.35482]
#set new line width and freeze it
		newpar $sigmaindex $sigma -1
		newpar $energyparamindex $e -1;#place the line at the next energy bin
		newpar $gaussnormindex  0.0 0.0001 -0.5 -0.5 0.5 0.5  ; #reset normalization of the gaussian allowing for negative normalization (absorption lines)
		thaw  $gaussnormindex
		tclout param $gaussnormindex
		newpar [expr $firstparambackground-2] 2.5; #reset background phoIndex
		newpar [expr $firstparambackground-1] 0.0001 0.001; #reset background normalization

		fit; error $gaussnormindex; #fit background together with the line

		if {$plotdata} {
			pl  ld rat
			show parameters
		}
#store value of c stat
		tclout stat
		set cnullmodelformat [format "%.3f" $cstatnullmodel]
		scan $xspec_tclout "%e" cstat
		set cstatformat [format "%.3f" $cstat]
		set deltac [expr $cstatnullmodel-$cstat]
		
		set deltacformat [format "%.3f" $deltac]
		tclout param $gaussnormindex
		scan $xspec_tclout "%e" norm
		set normformat [format "%.8f" $norm]
		tclout dof
		scan $xspec_tclout "%i" degof
		append outputtext "$cnullmodelformat\t$cstatformat\t$deltacformat\t$energyformat\t$normformat \t $degof\n"

#append cases that gave a negative delta c value in case later we want to analyse them
		if {$deltac<0.0} {
			puts "WARNING: delta C is negative"
			append 	outputlog "$cnullmodelformat\t$cstatformat\t$deltacformat\t$energyformat\t$normformat\t $sigma \t $deltav \t $degof \n"
		}
		set TIME_taken_fit [expr [expr [clock clicks -milliseconds] - $TIME_start_fit]/1000.0]
		puts "\n Fitting line at $e took = $TIME_taken_fit s"
		set totaltime [expr $totaltime+$TIME_taken_fit]
	}
# Open the file to put the results in.
	set fileid [open cstatlinescan_$deltav.dat w]
	
	puts $fileid $outputtext
	close $fileid

}

set fileid [open cstatlinescan.log w]
puts $fileid $outputlog

#log total time taken
set totaltimeminutes [expr $totaltime/60.0]
puts "Total time taken: $totaltimeminutes m "
