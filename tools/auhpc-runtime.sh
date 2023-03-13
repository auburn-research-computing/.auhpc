#!/bin/bash

#  auhpc-tools by the Auburn HPC Admins
#  auhpc-tools.sh | 03.01.23
#  ---------------------------------------------------------
#  https://github.com/auburn-research-computing/.auhpc
#  ---------------------------------------------------------
#  automate runtime configuration and environment
#  ---------------------------------------------------------

#### begin runtime options ####

# modify to target a specific build and runtime environment

target_compiler="gcc"
target_compiler_version="8.4.0"
target_runtime="R"
target_runtime_version="4.2.2"
target_runtime_feature="devtools"

#### end runtime options ####

[[ "$0" == "${BASH_SOURCE}" ]] && { echo -e "usage: [.|source] ${0}\n\n"; exit; }

script=$(readlink -f ${BASH_SOURCE[0]})
prefix=$(dirname ${script})
name=$(echo ${script} | awk -F'/' '{print $NF}' | cut -d'.' -f1)
config="${prefix}/${name}.cfg"

source "${config}"

source_prefix="${target_runtime_version}/${target_compiler}/${target_compiler_version}"
source_libs="${source_trunk_lib}/${source_prefix}"
source_devs="${source_trunk_dev}/${source_prefix}"
source_profiles="${source_trunk_profile}/${source_prefix}"
source_dev="${source_devs}/${source_item_dev}"
source_profile="${source_profiles}/${source_item_profile}"
target_libs="${target_trunk_libs}/${target_runtime_version}/${target_compiler}/${target_compiler_version}"

echo -e "\nAUHPC :: automation tools :: ${target_runtime} :: ${name}\n"
echo -e "loading configuration from: ${config}\n"
echo -e "--- environment settings ----\n"
echo -e "build environment: ${target_compiler}/${target_compiler_version}"
echo -e "runtime environment: ${target_runtime}/${target_runtime_version}"
echo -e "custom library path: ${source_libs}"
echo -e "${target_runtime} build settings: ${target_dev} -> ${source_dev}"
echo -e "${target_runtime} profile: ${target_profile} ->${source_profile}\n"

read -n1 -p "switch to this ${target_runtime} environment (y/N)? " response

[[ ! "${response}" =~ (Y|y) ]] && { echo -e "\n\n${name} cancelled. exiting.\n\n"; return 0; }

# set base environment

module load ${target_compiler}/${target_compiler_version}
module load ${target_runtime}/${target_runtime_version}

echo -e "\n\n------ source paths :: script-generated configuration data directories ------\n"
echo -ne "build configuration: ${source_devs} ... "
[[ -d ${source_devs} ]]  && echo "OK" || { echo "NEW"; "creating new ${source_devs} ... "; mkdir -p ${source_devs} &>/dev/null && echo "OK" || { echo "FAIL"; return 1; } } 

echo -ne "${target_runtime} profile: ${source_profiles} ... "
[[ -d ${source_profiles} ]] && echo "OK" || { echo "NEW"; echo -ne "creating new ${source_profiles} ... "; mkdir -p ${source_profiles} &>/dev/null && echo "OK" || { echo "FAIL"; return 1; } }

echo -e "\n------ target paths :: canonical ${target_runtime} configuration paths ------\n"
echo -ne "library path: ${target_libs} ... "
[[ -d ${target_libs} ]] && echo "OK" || { echo "NEW"; echo -ne "creating new ${target_libs} ... "; mkdir -p ${target_libs} &>/dev/null && echo "OK" || { echo "FAIL"; return 1; } }

echo -ne "build & user environment: ${target_trunk_dev} ... "
[[ -d ${target_trunk_dev} ]] && echo "OK" || { echo "NEW"; echo -ne "creating new ${target_trunk_dev} ... "; mkdir -p ${target_trunk_dev} &>/dev/null && echo "OK" || { echo "FAIL"; return 1; } } 

echo -e "\n------ source data :: script generated configuration files ------\n"
echo -e "data item 1: ${source_item_profile}"
echo -ne "\n- staging ${source_item_profile} template ... "

cp ${base_item_profile} ${source_profile} &>/dev/null && echo "OK" || echo "FALSE"; result="OK"

echo -ne "- writing environment configuration to ${source_item_dev} ... "

welcome="Welcome, ${USER}: ${target_runtime}${target_runtime_version} (${target_compiler}/${target_compiler_version})\nenvironment set by auhpc automation [$(date +'%m.%d.%Y')]"
goodbye="Goodbye, ${USER}: ${target_runtime}${target_runtime_version} (${target_compiler}/${target_compiler_version})"

sed -i "s|AUHPC_R_WELCOME|${welcome}|g" ${source_profile} 2>/dev/null || result="FAIL"
sed -i "s|AUHPC_R_LIBPATHS|\'${source_libs}\'|g" ${source_profile} 2>/dev/null || result="FAIL"
sed -i "s|AUHPC_R_GOODBYE|${goodbye}|g" ${source_profile} 2>/dev/null || result="FAIL"

echo "${result}"
echo -ne "- activating ${source_item_profile} ... "

target-enable ${source_profile} ${target_profile} && export R_LIBS_USER=${target_profile} && echo -e "OK" || echo "FAIL"

echo -e "\ndata item 2: ${source_item_dev}\n"
echo -ne "- staging ${source_item_dev} template ... "
cp ${base_item_dev} ${source_dev} && echo "OK" || echo "FALSE"

echo -ne "- enabling ${target_dev} symbolic link ... " && target-enable ${source_dev} ${target_dev} && echo "OK" || echo "FAIL"
echo -e "\n* ${target_compiler} ${target_compiler_version}->${target_runtime} ${target_runtime_version} base environment configuration complete.\n"

read -n1 -p "feature \"${feature_name}\" has been selected. configure the environment (y/N)?" response

[[ ! "${response}" =~ (Y|y) ]] && { echo -e "\n\n${name} cancelled. exiting.\n\n"; return 0; }

echo -e "\n\n------ features :: ${feature_name} ------\n"

cat ${base_item_dev} ${feature_item_dev} > ${source_dev}

modules=( $(cat ${feature_module_list}) )

echo -ne "${feature_name} environment modules (${#modules[@]}):\n"

module_names=""

break=1; for module in ${modules[@]}; do 
    module_name=$(echo -ne "${module}" | cut -d'/' -f1)
    echo -ne "loading ${module_name} ... "
    module load ${module} &>/dev/null && echo "OK" || echo "FAIL"
    #(( (${break} % 5) == 0 )) && term=$"\n"|| term=","
    #module_names+="$(printf '%s ' ${module_name})"
    #break=$(( break+=1 ))
done

read -n1 -p "run ${feature_name} package installation and setup script (y/N)?" response 
echo -e "\n\n"

[[ ! "${response}" =~ (Y|y) ]] && echo -e "skipping ${feature_name} installation, review steps \
in ${feature_setup_script} to run manually\n" && \
echo -e "\ndone. ${target_runtime}${target_runtime_version} (${target_compiler}/${target_compiler_version}) environment loaded\n\n"  && \
return 1

${feature_setup_command} ${feature_setup_script} || echo -e "\n${feature_name} setup failed:${feature_setup_command} ${feature_setup_script}\n"

#sed -i "s|AUHPC_R_FEATURE_LIB1|\'${feature_name}\'|g" ${source_profile} 2>/dev/null || result="FAIL"
echo "library('${feature_name}')" >> ${target_profile}

echo -e "\ndone. ${target_runtime}${target_runtime_version} (${target_compiler}/${target_compiler_version}) environment loaded\n\n"

