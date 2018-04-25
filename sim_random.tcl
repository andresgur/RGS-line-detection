#! /bin/env tclsh
# Generate N fake spectra from the same input model after fitting the rgs data contained in the folder with the power law background model
# using 90% confidence intervals for the background parameters. The source model parameters are fix in the simulations. All the rgs data must be contained in the folder (groupped to 1 and ungroupped source and background files)
############################################

#Return TCL results for XSPEC commands.
set xs_return_result 1

###################################
########### parameters ############
###################################

#number of 
set ndistributions 10000
set TAG "Sim_random: "
set Emin 0.5
set Emax 1.5

#whether to plot the faked spectra
set toplot 0

#read arguments
#--------------------
set params ""

for {set j 0} {$j<$argc} {incr j} {

switch -glob -- [lindex $argv $j] {
-m* {incr j;set modelname [lindex $argv $j]}
-p* {incr j;set params [lindex $argv $j]}
-* {puts "$TAG Error unknown option [lindex $argv $j] [lindex $argv [expr $j +1]]"; exit}
}
}

#exit program if no observation id were provided
if {[info exists modelname]==0} {
puts "$TAG No model was provided. Usage: -m(odel) {model_name} -p(arameters) {param1 delta & param2 &param3... (from the null_model)}";exit
}

#--------------------

# source procedures
source $::env(HOME)/scripts/bayesian_scripts/fit_procedures.tcl
source $::env(HOME)/scripts/bayesian_scripts/RGS/cstatlinescan_procedures.tcl

# Keep going until fit converges.
query yes

# Open xwindow
cpd /xs

# Set fitting method to migrad
method leven

statistic cstat

setplot en

#load and fit the spectra and background
loadandfit $modelname $params
setplot rebin 5 5
pl ld residuals

############################################
### Now simulate a series of faked #########
### 		spectra            #########
############################################

#prepare output dir
file mkdir simulations

# Load in an ungrouped spectrum
data none

#find rgs spectrum file (name is r12 if the data is the result of one single observation or r1 if more than obs was stacked)
#no complain option to avoid the program to break if no file is found
set spectrafiles [glob -nocomplain -type f r1_o1_srspec*.fit]

#if no data was found with r1, look for r12, if no data is found it will stop here
if { 0 == [llength $spectrafiles] } {
puts "No files found starting with 'r1'--> loading files with prefix r12"
set spectrafiles [glob -type f r12_o1_srspec*.fit]
set backgroundfiles [glob -type f r12_o1_bgspec*.fit]
set rmffiles [glob -type f r12_o1_rmf*.fit]
} else {
set backgroundfiles [glob -type f r1_o1_bgspec*.fit]
set rmffiles [glob -type f r1_o1_rmf*.fit]
}

#sort the list;0 index is the ungroupped; 1 the groupped
set spectrumungroupped [lindex [lsort $spectrafiles] 0]
#find ungroupped background file
set backgroundungroupped [lindex [lsort $backgroundfiles] 0]
data  $spectrumungroupped  
set rmf [lindex $rmffiles 0]

data $spectrumungroupped

#ignore bad channels and low and high energies
#ig bad;ig *:**-$Emin *:$Emax-**

#get number of parameters
tclout modpar
scan $xspec_tclout "%i" nparams

# read exposure time from file
tclout expos
set exposuretime $xspec_tclout
puts "Exposure time: $exposuretime"

# Loop through all of the data
for {set i 0} {$i < $ndistributions} {incr i} {
puts "\n-------------------------------------\n"
puts "Simulating spectra $i/$ndistributions with spectrum, background and rmf: $spectrumungroupped, $backgroundungroupped and $rmf"
puts "\n-------------------------------------\n"

# Set up the model for the simulation without the background component
model "$modelname & $params"

# Fake the data (par1=filename par2=exposure time)
faker $backgroundungroupped $rmf RGS_sim_$i\.fak $exposuretime

#move fake spectra to output dir removing any previous simulations

file rename -force RGS_sim_$i.fak simulations/

file rename -force RGS_sim_$i\_bkg.fak simulations/

# Plot the fake
#Comment to increase speed
if {$toplot} {
ig bad;ig *:**-$Emin *:$Emax-**
setplot rebin 5 5
plot ldata 
}

} ;#end of fake spectra generation loop

#./$::env(HOME)/scripts/bayesian_scripts/groupall RGS_sim 1

exit
