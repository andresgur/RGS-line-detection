#! /bin/env tclsh
#Procedures for RGS data fitting


#Loads RGS data spectrum with background and the background file as a separate spectra. All files must be in the
#working directory
#----------------------------------------------------------------------------------
proc loadcurrent_rgs {} {

#find rgs spectrum file (name is r12 if the data is the result of one single observation or r1 if more than obs was stacked)
#no complain option to avoid the program to break if no file is found
set spectrafiles [glob -nocomplain -type f r1_o1_srspec*_min1.fit]

#if no data was found with r1, look for r12, if no data is found it will stop here
if { 0 == [llength $spectrafiles] } {
puts "No files found starting with 'r1'--> loading files with prefix r12"
set spectrafiles [glob -type f r12_o1_srspec*_min1.fit]
set backgroundfiles [glob -type f r12_o1_bgspec*_min1.fit]
} else {
set backgroundfiles [glob -type f r1_o1_bgspec*_min1.fit]
}


#grab the first coincidence
#source
set spectrumgroupped [lindex $spectrafiles 0]

#background
set background [lindex $backgroundfiles 0]

data 1:1 $spectrumgroupped 2:2 $background

puts "Adding background to source spectrum"
back 1 none

show data
}
#----------------------------------------------------------------------------------

#fit frozen model with the power law to account for the background. 
#arguments: number of parameters of the model
#----------------------------------------------------------------------------------
proc fitbackground {nparams} {

#ignore bad and channels with high background
ignore bad;ignore *:**-0.5 *:1.5-**

#freeze all parameters except background power law
set firstparambackground [expr $nparams/2+1]

#set all background parameters to 0 and frozen except for the power law in the background spectrum
for {set i $firstparambackground} {$i < $nparams-1} {incr i} {
	  newpar $i 0 -1 0 0; # parameter value set to 0, frozen , and change low limits so xspec does not complain about the value being outside boundaries
}

#reset power law background
set backIndex [expr $firstparambackground-2]
set backNorm [expr $firstparambackground-1]
newpar $backIndex 2.5
newpar $backNorm 0.0001 

show parameters
#do the fit
renorm;fit;shakefit $firstparambackground; #tell shakefit to explore only the parameters that are free (only from the source; background params are tight to the source model)
show parameters
} ;#end of proc


#######################################################################################

#fit frozen model with the power law to account for the background and a line at the specific energy linewidth in energy sigma
proc fitbackgroundwithline {nparams energyLine {sigma 0}} {
	
#ignore bad and channels with high background
ignore bad;ignore *:**-0.5 *:1.5-**

#get index of variable parameters
set firstparambackground [expr $nparams/2+1]
set sigma_index [expr $firstparambackground-4]
set gaussnormindex [expr $firstparambackground-3]
set backIndex [expr $firstparambackground-2]
set backNorm [expr $firstparambackground-1]

#reset variable parameters
newpar $gaussnormindex 0.0 0.001 -0.5 -0.5 0.5 0.5 
newpar $backIndex 2.5
newpar $backNorm 0.0001
newpar $sigma_index $sigma -1


#set all background parameters to 0 and frozen except for the power law in the background spectrum
for {set i $firstparambackground} {$i < $nparams-1} {incr i} {
	  newpar $i 0 -1 0 0; # parameter value set to 0, frozen , and change low limits so xspec does not complain about the value being outside boundaries
}

show parameters
tclout param $gaussnormindex
puts "Line normalization parameter: $xspec_tclout"
renorm;fit; shakefit $firstparambackground ;#tell shakefit to explore only the parameters that are free (only from the source; background params are tight to the source model so no point in looping through them)
} 

#######################################################################################
#load faked spectra with index nspectrum (looks for RGS spectra ended with fak.g)
proc loadgrouppedfake {nspectrum directory} {
	cd $directory
	data 1:1 RGS_sim_$nspectrum.fak.g 2:2 RGS_sim_$nspectrum\_bkg.fak.g
	puts "Adding background to source spectrum"
	back 1 none

	#load response matrix
	set rmffiles [glob -nocomplain -type f r1_o1_rmf_*.fit]

	#if no data was found with r1, look for r12, if no data is response matrix is found the script will break here
	if { 0 == [llength $rmffiles] } {
		set rmffiles [glob -type f r12_o1_rmf.fit]
	}
	res 2 [lindex $rmffiles 0]
	show data 
	cd ..
}

