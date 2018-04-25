#! /bin/env tclsh
# Fit n fake spectra with the input model for the 'source' adding a gaussian at the specified energy and a power law to account for the background and outputs the result to ASCII file called 'fit_result_LINE_$energyline_$nspectra.dat'
# input parameters are: the number of fake spectra, the position in keV of the line, the null hypothesis model and the parameters of this one
# author Andres Gurpide Lasheras email: andres.gurpide@gmail.com


###########################
######## parameters #######

set plotdata 0; #boolean to decide whether to plot every fit or not

#-------------------------------------------------------------------

# Return TCL results for XSPEC commands.
set xs_return_result 1

# Keep going until fit converges.
query yes

# source procedures
source $::env(HOME)/scripts/bayesian_scripts/fit_procedures.tcl
source $::env(HOME)/scripts/bayesian_scripts/RGS/cstatlinescan_procedures.tcl
# ----------------------------------------------------------

#read arguments

for {set j 0} {$j<$argc} {incr j} {

switch -glob -- [lindex $argv $j] {
-m* {incr j;set modelname [lindex $argv $j]}
-p* {incr j;set params [lindex $argv $j]}
-n* {incr j;set nspectra [lindex $argv $j]}
-E* {incr j; set energyLine [lindex $argv $j]} ;#energy of the line to be placed in the fit
-* {puts "Error unknown option [lindex $argv $j] [lindex $argv [expr $j +1]]"; exit}
} ;#end of the switch-case
}; #end of the for loop

#exit program if no observation id were provided
if {[info exists energyLine]==0 ||  [info exists modelname]==0 ||  [info exists nspectra]==0 || [info exists params]==0} {
puts "One or more arguments are missing. Usage:xspec $argv0 -m(odel) <mod> -p(arameters) {param1 & param2 & ...} -n {number of spectra to process} -E(nergy) {line energy in keV}";exit
}

parallel leven 4
parallel error 4
parallel steppar 4 

# Set fitting method to migrad
method leven

statis cstat


#prepare window to plot data or not
if {$plotdata} {
# Open xwindow
cpd /xw
# Define plotting details
setplot energy
setplot add
}



set outputtext ""

#total time
set totaltime 0
# Loop through all data
for {set i 0} {$i < $nspectra} {incr i} {

	#log current spectrum
	puts "Processing spectrum $i/$nspectra"
	set TIME_start [clock clicks -milliseconds]	

	# load the grouped spectral file 
	loadgrouppedfake $i
	
	#fit background with line
	fitbackgroundwithline $modelname $params $energyLine
	
	#plot data if the boolean is set to true
	if {$plotdata} {
		rebin 5 5
		plot ld ra
		}
	# -----------------------------------------------
	# Get the fit statistic
  	tclout stat 
  	set chi [string trim $xspec_tclout]
  	tclout dof 
  	set deg [string trim $xspec_tclout]
	# ---------------------------------
	# Print out the result to the file. This writes the current
	# chi-squared, and the values and error bars for parameters 3,2.
  	#puts $fileid "$i [lindex $chi 0] [lindex $deg 0]"
	append outputtext "$i [lindex $chi 0] [lindex $deg 0] \n"	

	#compute time taken
	set TIME_taken [expr [expr [clock clicks -milliseconds] - $TIME_start]/1000.0]
	puts "\n Time taken to fit spectrum $i = $TIME_taken s \n"
	set totaltime [expr $totaltime+$TIME_taken]

	# Reset data and model
	reset
}

# Open the file to put the results in.
set fileid [open fit_result_LINE_$energyLine\_$nspectra.dat w]
puts $fileid $outputtext
# Close the file.
close $fileid

#log total time taken
set totaltimeminutes [expr $totaltime/60.0]
puts "Total time taken: $totaltimeminutes m "

