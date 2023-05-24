#!/bin/bash
set -e

# Get suffix of the template directory
read -p 'Choose Suffix: ' arg
if ! [ "${arg}" == "" ]; then 
    suffix="_${arg}"
else
    echo "This will procede without a suffix and the template directory will be overwritten. You have 10s to cancel."
    sleep 10
    suffix=""
fi

# Fibre Orientation Distribution estimation (multi-tissue spherical deconvolution)
for_each subjects/* : dwi2fod msmt_csd IN/dwi_upsampled.mif group_average_response_wm.txt IN/wmfod.mif group_average_response_gm.txt IN/gm.mif group_average_response_csf.txt IN/csf.mif -mask IN/mask_upsampled.mif -force
for_each subjects/* : rm IN/dwi_upsampled.mif

# Joint bias field correction and intensity normalisation
for_each subjects/* : mtnormalise IN/wmfod.mif IN/wmfod_norm.mif IN/gm.mif IN/gm_norm.mif IN/csf.mif IN/csf_norm.mif -mask IN/mask_upsampled.mif -force
for_each subjects/* : rm IN/wmfod.mif

# Generate a study-specific unbiased FOD template
rm -rf template/fod_input template/mask_input
mkdir -p template/fod_input; mkdir -p template/mask_input

#for_each subjects/* : ln -sf IN/wmfod_norm.mif template/fod_input/PRE.mif
#for_each subjects/* : ln -sf IN/mask_upsampled.mif template/mask_input/PRE.mif

# If we wanted to select only a sample of the data
for_each `ls -d subjects/*-midcycle* | sort -R | tail -8` : ln -sfr IN/wmfod_norm.mif template/fod_input/PRE.mif ";" ln -sfr IN/mask_upsampled.mif template/mask_input/PRE.mif; 
for_each `ls -d subjects/*-premenstrual* | sort -R | tail -8` : ln -sfr IN/wmfod_norm.mif template/fod_input/PRE.mif ";" ln -sfr IN/mask_upsampled.mif template/mask_input/PRE.mif; 
for_each `ls -d subjects/*-interictal* | sort -R | tail -8` : ln -sfr IN/wmfod_norm.mif template/fod_input/PRE.mif ";" ln -sfr IN/mask_upsampled.mif template/mask_input/PRE.mif; 
for_each `ls -d subjects/*-ictal* | sort -R | tail -8` : ln -sfr IN/wmfod_norm.mif template/fod_input/PRE.mif ";" ln -sfr IN/mask_upsampled.mif template/mask_input/PRE.mif;
for_each `ls -d subjects/*-preictal* | sort -R | tail -8` : ln -sfr IN/wmfod_norm.mif template/fod_input/PRE.mif ";" ln -sfr IN/mask_upsampled.mif template/mask_input/PRE.mif;
for_each `ls -d subjects/*-postictal* | sort -R | tail -8` : ln -sfr IN/wmfod_norm.mif template/fod_input/PRE.mif ";" ln -sfr IN/mask_upsampled.mif template/mask_input/PRE.mif;

./population_template template/fod_input -mask_dir template/mask_input template/wmfod_template.mif -voxel_size 1.25 -force

# Register all subject FOD images to the FOD template
for_each subjects/* : mrregister IN/wmfod_norm.mif -mask1 IN/mask_upsampled.mif template/wmfod_template.mif -nl_warp IN/subject2template_warp.mif IN/template2subject_warp.mif -force

# Compute the template mask (intersection of all subject masks in template space)
for_each subjects/* : mrtransform IN/mask_upsampled.mif -warp IN/subject2template_warp.mif -interp nearest -datatype bit IN/dwi_mask_in_template_space.mif -force
mrmath subjects/*/dwi_mask_in_template_space"${suffix}"s.mif min "template/template_mask${suffix}.mif" -datatype bit -force

# Check at this stage that the resulting template mask includes all regions of the brain that are intended to be analysed
