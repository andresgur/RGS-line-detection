#! /bin/env tclsh

#Loads RGS data spectrum and background and performs the fit, adding the background power law model to the model and parameters provided
proc loadandfit {modelname params} {

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

data 1:1 $spectrumgroupped

bac none

puts "Background added to source file"

show data

data 2:2 $background

return [fitbackground $modelname $params]

}

#######################################################################################

#fit frozen model adding the power law to account for the background. The input model should be without taking into account the background. Returns the name of the new model (model+pow)
proc fitbackground {modelname params} {

#ignore bad and channels with high background
ignore bad;ignore *:**-0.5 *:1.5-**
################################
#add power law background params
################################
puts "Adding power law background to the model"
append modelname "+ pow"
#add background (phoIndex and norm)
append params " &2.0 & 0.1 &"

#set model
model "$modelname & $params /*"

#get number of parameters of the model
tclout modpar
scan $xspec_tclout "%i" nparams

###BACKGROUND ADJUSTEMENT###
#freeze all parameters except background power law
set firstparambackground [expr $nparams/2+1]

freeze 1-[expr $firstparambackground-3]
#set all background parameters to 0 except for the power law in the background spectrum and frozen
for {set i $firstparambackground} {$i < $nparams-1} {incr i} {

#if one of the parameters is the energy of the cut of the cuttofpl avoid setting it to zero so the program does not stop
tclout pinfo $i
  if [regexp HighECut $xspec_tclout] {
	newpar $i 0.1 -1
	continue
}
  newpar $i 0 -1
}
show parameters
#do the fit
fit;shakefit
show parameters
return $modelname ; #return the name of the model with the added power law
} ;#end of proc


#######################################################################################

#fit frozen model adding the power law to account for the background and a line at the specific energy. The input model should be without taking into account the background. Returns the new model created (absorption(model+gauss) +pow)
proc fitbackgroundwithline {modelname params energyLine} {

	#ignore bad and channels with high background
	ignore bad;ignore *:**-0.5 *:1.5-**

##########################################
#add gaussian line + power law background  
##########################################

	puts "Adding power law background to the model and energy line at: $energyLine"
	set modelgauss [regsub -all {\)} $modelname {+gaussian)+pow}]
	puts "Model with background and line: $modelgauss"
	#add line (energy, width and norm) and background (phoIndex and norm) 
	append params "& $energyLine -1 & 0 -1 &  0.0 0.0001 -0.5 -0.5 0.5 0.5 &2.0 & 0.01 &"

	#set model
	model "$modelgauss & $params /*"

	#get number of parameters of the model	
	tclout modpar
	scan $xspec_tclout "%i" nparams

###BACKGROUND ADJUSTEMENT###
#freeze all parameters except background power law
	set firstparambackground [expr $nparams/2+1]

#get index of the gaussian norm
	set gaussnormindex [expr $firstparambackground-3]

#freeze all parameters from the model except the power law
	freeze 1-[expr $firstparambackground-3]

	thaw $gaussnormindex

#set all background parameters to 0 except for the power law in the background spectrum and frozen
	for {set i $firstparambackground} {$i < $nparams-1} {incr i} {

#if one of the parameters is the energy of the cut of the cuttofpl avoid setting it to zero so the program does not stop
		tclout pinfo $i
		if [regexp HighECut $xspec_tclout] {
			newpar $i 0.1 -1
			continue
		}
	  newpar $i 0 -1
}
	show parameters
	fit;shakefit  ; #shakefit gets stuck and it's too slow probably due to the fact that the error command, when it finds a new minimum reruns again. Then it finds a minimum again and reruns, reseting the number maximum number of iterations. Sometimes it gets stuck between two minima and it goes on forever. To avoid this add nonew command so it does not rerun the error command when it finds a new minimum
	show parameters
	return $modelgauss
} 

#######################################################################################
#load faked spectra with index nspectrum (looks for RGS spectra ended with fak.g)
proc loadgrouppedfake {nspectrum} {
	data 1:1 RGS_sim_$nspectrum.fak.g
	bac none
 	data 2:2 RGS_sim_$nspectrum\_bkg.fak.g

	#load response matrix
	set rmffiles [glob -nocomplain -type f r1_o1_rmf_*.fit]

	#if no data was found with r1, look for r12, if no data is response matrix is found the script will break here
	if { 0 == [llength $rmffiles] } {
		set rmffiles [glob -type f r12_o1_rmf.fit]
	}
	res 2 [lindex $rmffiles 0]
	show data 
}

