#!/bin/bash

#  auhpc-tools by the Auburn HPC Admins
#  auhpc-tools.sh | 03.01.23
#  ---------------------------------------------------------
#  https://github.com/auburn-research-computing/.auhpc
#  ---------------------------------------------------------
#  outer logic, setup script for performing required 
#  initialization  filesystem, and user setup operations
#  ---------------------------------------------------------

# script should be sourced, not executed directly
[[ "$0" == "${BASH_SOURCE}" ]] && { echo -e "usage: [.|source] ${0}\n\n"; exit; }

# attempt to determine full path to this script
SCRIPT=$(readlink -f ${BASH_SOURCE[0]})

# user input handler, TODO: integrate with scripting tools
function confirm() {
    local msg="${1}"; local fatal="${2}"; [[ -z ${fatal} ]] && fatal=1
    printf "\n"; read -p "$(echo -e ${msg}) (y\N)? " response
    local response=${response,,}
    if [[ ! $response =~ ^(yes|y) ]]; then
        if (( fatal == 1 )); then 
        printf "\nscript progress cancelled. exiting.\n\n"; return 1; else
        printf "\noperation cancelled. skipping.\n"; return 1; fi
    fi
    #printf "\n"
}

# configuration profiles contain some subset of variables, filesystem locations, 
# or functions  for specific software workflows, see README 

# from a provided profile name or filename, determine associated
# configuration files, import associated variables, and search known global arrays 
# for associated load-time functions to be called

# usage: read_profile <name|path>

function read_profile() {
	
	# must provide a profile name or filename
	[[ ${#} -ne 1 ]] || [[ -z ${1} ]] && { echo -e "usage: ${FUNCNAME[0]} <profile_name>"; return 1; }
	
	local name="${1}"

	# if the provided \"name\" is a valid file path, import it directly, otherwise append $name to the defined
	# profile subdirectory and import all *.cfg files
	local profile="${SCRIPT_PROFILES}/${name}/*.cfg"; [[ -f ${name} ]] && { local profile="${name}"; name="script"; }
	
	echo -ne "loading ${name} configuration profile ... " 

	# source the determined file(s) to import variables
	source ${profile} 2>/dev/null && echo -e "OK" || { echo -e "FAIL"; return 1; }

	# locate any associated load-time functions and execute
	for i in $(seq 1 2 ${#PROFILE_OUT[@]}); do
    	key=$(echo ${PROFILE_OUT[${i}-1]})
		[[ "${key}" =~ ${name}$ ]] && ${PROFILE_OUT[${i}]} 2>/dev/null && return 0
	done

	return 0

}

# load the script profile, which attempts to determine essential filesystem locations
# and other metadata required for subsequent operations

# usage: script-init

script-init() {
	
	# check that SCRIPT, defined above, references a valid file
	[[ -z ${SCRIPT} ]] || [[ ! -f ${SCRIPT} ]] && { echo -e "invalid script identifer, check SCRIPT in source\n"; return 1; }

	# title
	echo -e "\n$(echo ${SCRIPT:-automation} | rev | cut -d'/' -f1 | rev) :: script intialization\n" 

	echo -ne "locating script configuration profile ... "	
	
	# we have not yet sourced the core profile, so  
	local prefix=$(echo ${SCRIPT} | grep -oE "^.*/[^.*$]*")
	local config="${prefix}.cfg"

	[[ -z ${config} ]] || [[ ! -f ${config} ]] && { echo "unable to locate core settings for ${SCRIPT}"; return 1; } || echo ${config} | awk -F'/' '{printf "OK (%s)\n",$NF}'

	read_profile ${config}

	(( ! ${?} == 0 )) && { echo -e echo "unable to read ${config}, try \"source ${config}\" to debug." >&2; return 1; }

	if [[ -z ${SCRIPT_PROFILE} ]]; then
		echo -e "no environment profile found. using existing system environment settings."
		echo -e "if a  SCRIPT_PROFILE in ${config} to set the base environment"
		return 1
	fi

	confirm "initialize ${SCRIPT_PROFILE} profile" && script-profile-init

	echo -e "\nscript initialization complete. done.\n\n"

	return 0

}

script-profile-init() {

	[[ -z ${SCRIPT_PROFILE} ]] && { echo "invalid script profile identifer"; return 1; }

	read_profile ${SCRIPT_PROFILE}

	if [[ -z ${BASE_COMPILER} ]] || [[ -z ${BASE_COMPILER_VERSION} ]]; then
		echo "invalid compiler toolchain, check ${SCRIPT_PROFILE}"; return 1
	fi

	if [[ -z ${BASE_RUNTIME} ]] || [[ -z ${BASE_RUNTIME_PROFILE} ]]; then
		echo "invalid runtime, check ${SCRIPT_PROFILE}"; return 1
	fi

	confirm "initialize runtime" && script-runtime-init
	
	echo -e "\nscript runtime environment initialization complete"

	return 0

}

script-runtime-init() {

	# check to make sure the script config has been loaded and a core profile has been set

	if [[ -z ${BASE_COMPILER} ]] || [[ -z ${BASE_COMPILER_VERSION} ]]; then
		confirm "no compiler toolchain settings found in ${SCRIPT_PROFILE}"
		(( ${?} == 0 )) && script-profile-init || { echo -e "no profile available, check settings"; return 1; }
	fi

	script-toolchain-init

	if [[ -z ${BASE_RUNTIME} ]] || [[ -z ${BASE_RUNTIME_PROFILE} ]]; then
		confirm "no runtime profile settings found in ${SCRIPT_PROFILE}"
		(( ${?} == 0 )) && script-profile-init || { echo -e "no profile available, check settings"; return 1; }
	fi
	
	script-runtime-profile-init

	for i in $(seq 1 2 ${#RUNTIME_FUNCTIONS[@]}); do
    	key=$(echo ${RUNTIME_FUNCTIONS[${i}-1]})
		[[ "${key}" == "${BASE_RUNTIME}" ]] && ${RUNTIME_FUNCTIONS[${i}]} 2>/dev/null
	done

	profile-enable

	return 0

}

function script-toolchain-init() {

	if [[ "${@:1}" =~ ^(.*-)+(help|\?)$ ]]; then
		echo -e "${FUNCNAME[0]}: load a default or optionally specified compiler module and dependent R version."
		echo -e "usage: ${FUNCNAME[0]} [r_version] [compiler module]\nex. ${FUNCNAME[0]} 4.2.2 gcc/8.4.0\n\n" >&2 
		return 0
	fi
	
    local compiler="${2}"; [[ -z ${compiler} ]] && local compiler=${BASE_COMPILER}/${BASE_COMPILER_VERSION}
    
	confirm "load ${compiler} environment modules"; (( ! ${?} == 0 )) && return 1

	echo -ne "loading ${compiler} toolchain module(s) ... " 2>&1

    module load ${compiler} &>/dev/null && echo "OK" || { echo "FAIL"; return 1; }

	return 0

}

function script-runtime-profile-init() {

	read_profile ${BASE_RUNTIME}

	if [[ "${@:1}" =~ ^(.*-)+(help|\?)$ ]]; then
		echo -e "${FUNCNAME[0]}: load runtime from ${SCRIPT_PROFILE} or optionally specified module."
		echo -e "usage: ${FUNCNAME[0]} [software version] [runtime module]\nex. ${FUNCNAME[0]} R/2.2.1\n" >&2 
		return 0
	fi

	confirm "load ${RUNTIME_MODULE}/${RUNTIME_VERSION} (${BASE_COMPILER}/${BASE_COMPILER_VERSION}) environment modules"; (( ! ${?} == 0 )) && return 1
        
	echo -ne "\nloading ${RUNTIME_MODULE}/${RUNTIME_VERSION} module(s) ... " 2>&1
    
	module load ${RUNTIME_MODULE}/${RUNTIME_VERSION} &>/dev/null && echo "OK" || { echo "FAIL"; return 1; }

	return 0

}

function profile-disable() {

	[[ ! ${#} -eq 1 ]] && [[ ! -e ${RUNTIME_CONFIG_DEFAULT} ]] && return 1
	
	echo -ne "\nrenaming ${RUNTIME_CONFIG_DEFAULT} as ${RUNTIME_CONFIG_BASE} ... "
	
	mv ${RUNTIME_CONFIG_DEFAULT} ${RUNTIME_CONFIG_BASE} &>/dev/null
	
	(( ${?} == 0 )) && echo -e "OK" || { echo -e "FAIL"; return 1; }

	return 0

}

function profile-enable() {

	local profile=${1}; [[ -z ${profile} ]] && [[ ! -z ${RUNTIME_CONFIG_DEFAULT} ]] && profile=${RUNTIME_CONFIG_DEFAULT}
	
	if [[ -L ${profile} ]]; then
		echo -ne "removing existing link at ${profile} ... "
		rm ${profile} &>/dev/null && echo -e "OK" || { echo -e "FAIL\n\nerror: unable to remove active symlink ${RUNTIME_CONFIG_DEFAULT} => ${RUNTIME_CONFIG_PROFILE}\n"; return 1; }
	fi

	if [[ -f ${profile} ]]; then
		confirm "there is an existing file at ${profile}, rename and activate ${RUNTIME_CONFIG_PROFILE}"
		(( ${?} == 0 )) && profile-disable || return 1
	fi

	if [[ ! -e ${profile} ]]; then
		echo -ne "symlinking ${RUNTIME_CONFIG_DEFAULT} to ${RUNTIME_CONFIG_PROFILE} ... "
		ln -s ${RUNTIME_CONFIG_PROFILE} ${RUNTIME_CONFIG_DEFAULT} &>/dev/null && echo -e "OK" || { echo -e "FAIL\n\nerror: unable to create symlink ${PROFILE_TARGET} => ${SCRIPT_PROFILE}\n"; return 1; }
	else 
		echo -e "\nprofile activation failed\n" >&2; return 1
	fi

	[[ -L ${profile} ]] && echo "\n${BASE_RUNTIME} profile activated (${RUNTIME_CONFIG_NAME} -> ${RUNTIME_CONFIG_PROFILE})"

	return 0 

}


