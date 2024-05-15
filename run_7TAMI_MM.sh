#!/bin/bash

BIDS_dataset=bids_dataset_test

BIDS_ID_SUBJECTS=000
BIDS_SES_SUBJECTS=ses-1

path_template_WB=7TAMI_MM_templates/WholeBrain_LR
path_template_MB=7TAMI_MM_templates/MidBrain_HR

sub_brainmask=${BIDS_dataset}/derivatives/brainmask/sub-${BIDS_ID_SUBJECTS}/sub-${BIDS_ID_SUBJECTS}_${BIDS_SES_SUBJECTS}_brainmask.nii.gz

sub_T1map=${BIDS_dataset}/sub-${BIDS_ID_SUBJECTS}/${BIDS_SES_SUBJECTS}/anat/sub-${BIDS_ID_SUBJECTS}_${BIDS_SES_SUBJECTS}_T1map.nii.gz
sub_QSM=${BIDS_dataset}/sub-${BIDS_ID_SUBJECTS}/${BIDS_SES_SUBJECTS}/anat/sub-${BIDS_ID_SUBJECTS}_${BIDS_SES_SUBJECTS}_QSM.nii.gz
sub_R2s=${BIDS_dataset}/sub-${BIDS_ID_SUBJECTS}/${BIDS_SES_SUBJECTS}/anat/sub-${BIDS_ID_SUBJECTS}_${BIDS_SES_SUBJECTS}_R2s.nii.gz

template_brainmask=${path_template_WB}/7TAMI_brainmask.nii.gz
template_T1map=${path_template_WB}/7TAMI_T1map.nii.gz
template_QSM=${path_template_WB}/7TAMI_QSM.nii.gz
template_R2s=${path_template_WB}/7TAMI_R2s.nii.gz

path_sub2template_transfo_WB=${BIDS_dataset}/derivatives/transfo/sub-${BIDS_ID_SUBJECTS}

mkdir -p ${path_sub2template_transfo_WB}

sub2template_transfo_WB=${path_sub2template_transfo_WB}/sub-${BIDS_ID_SUBJECTS}_2_7TAMI_WB

#STEP1

#first registration subject to 7TAMI whole-brain template (at 1 mm iso)

antsRegistration --verbose 1 --dimensionality 3 --float 0 --collapse-output-transforms 1 \
	--output ${sub2template_transfo_WB} \
	--interpolation Linear --use-histogram-matching 0 --winsorize-image-intensities [ 0.005,0.995 ] \
	-x [ $template_brainmask,$sub_brainmask ]  \
	--initial-moving-transform [$template_T1map,$sub_T1map,1 ] \
	--transform Rigid[ 0.1 ] --metric MI[$template_T1map,$sub_T1map,1,32,Regular,0.25 ] \
	--convergence [ 1000x500x250x0,1e-6,10 ] --shrink-factors 8x4x2x1 --smoothing-sigmas 3x2x1x0vox \
	--transform Affine[ 0.1 ] --metric MI[ $template_T1map,$sub_T1map,1,32,Regular,0.25 ] \
	--convergence [ 1000x500x250x0,1e-6,10 ] --shrink-factors 8x4x2x1 --smoothing-sigmas 3x2x1x0vox \
	--transform SyN[ 0.1,3,0 ] \
	--metric CC[ $template_T1map,$sub_T1map,1,2] \
	--metric CC[ $template_R2s,$sub_R2s,1,2] \
	--metric CC[ $template_QSM,$sub_QSM,1,2] \
	--convergence [ 100x70x50x20,1e-6,10 ] --shrink-factors 8x4x2x1 --smoothing-sigmas 3x2x1x0vox -v

#STEP2

template_atlas_MB=${path_template_WB}/7TAMI_DGN.nii.gz

template_brainmask_MB=${path_template_MB}/7TAMI_mask.nii.gz
template_T1map_MB=${path_template_MB}/7TAMI_T1map.nii.gz
template_QSM_MB=${path_template_MB}/7TAMI_QSM.nii.gz
template_R2s_MB=${path_template_MB}/7TAMI_R2s.nii.gz

atlas_DGN_2_sub=${BIDS_dataset}/derivatives/atlases/sub-${BIDS_ID_SUBJECTS}_${BIDS_SES_SUBJECTS}_7TAMI_DGN.nii.gz

sub_T1map_resliced_2_MB=${sub2template_transfo_WB}_T1map_resliced_2_MB.nii.gz
sub_QSM_resliced_2_MB=${sub2template_transfo_WB}_QSM_resliced_2_MB.nii.gz
sub_R2s_resliced_2_MB=${sub2template_transfo_WB}_R2s_resliced_2_MB.nii.gz

#reslicing (at 0.4mm iso) and cropping to the 7TAMI mid-brain template from the subject warped (STEP1)

# FOR voxel-based analysis 

#T1map
antsApplyTransforms -d 3 -i $sub_T1map \
-o ${sub_T1map_resliced_2_MB} \
-r $template_T1map_MB  \
-t ${sub2template_transfo_WB}1Warp.nii.gz -t ${sub2template_transfo_WB}0GenericAffine.mat 

#QSM
antsApplyTransforms -d 3 -i $sub_QSM \
-o ${sub_QSM_resliced_2_MB} \
-r $template_T1map_MB  \
-t ${sub2template_transfo_WB}1Warp.nii.gz -t ${sub2template_transfo_WB}0GenericAffine.mat 

#R2s
antsApplyTransforms -d 3 -i $sub_R2s \
-o ${sub_R2s_resliced_2_MB} \
-r $template_T1map_MB  \
-t ${sub2template_transfo_WB}1Warp.nii.gz -t ${sub2template_transfo_WB}0GenericAffine.mat 

# FOR region-based analysis 

#7TAMI DGN
antsApplyTransforms -d 3 -i ${template_atlas_MB} \
-o ${atlas_DGN_2_sub} \
-r $sub_T1map    \
-t [${sub2template_transfo_WB}0GenericAffine.mat,1] \
-t ${sub2template_transfo_WB}1InverseWarp.nii.gz \
-n MultiLabel -v 1

#STEP3

#second MM registration subject cropped/warped (STEP2) to 7TAMI MM mid-brain template (at 0.4 mm iso)

sub2template_transfo_MB=${path_sub2template_transfo_WB}/sub-${BIDS_ID_SUBJECTS}_2_7TAMI_MB

antsRegistration --verbose 1 --dimensionality 3 --float 0 --collapse-output-transforms 1 \
 --output ${sub2template_transfo_MB} \
 --interpolation Linear --use-histogram-matching 0 --winsorize-image-intensities [ 0.005,0.995 ] \
 --transform SyN[ 0.1,3,0 ] \
 --metric CC[ $template_T1map_MB,$sub_T1map_resliced_2_MB,1,2] \
 --metric CC[ $template_R2s_MB,$sub_R2s_resliced_2_MB,1,2] \
 --metric CC[ $template_QSM_MB,$sub_QSM_resliced_2_MB,1,2] \
 --convergence [ 100x50x20x10,1e-6,10 ] --shrink-factors 8x4x2x1 --smoothing-sigmas 3x2x1x0vox

atlas_parc_LR_5lab_2_sub=${BIDS_dataset}/derivatives/atlases/sub-${BIDS_ID_SUBJECTS}_${BIDS_SES_SUBJECTS}_7TAMI_parc_LR_5lab.nii.gz
atlas_parc_LR_5lab_MB=${path_template_MB}/7TAMI_parc_LR_5lab.nii.gz

sub_T1map_warped_2_MB=${sub2template_transfo_MB}_T1map_warped_2_MB.nii.gz
sub_QSM_warped_2_MB=${sub2template_transfo_MB}_QSM_warped_2_MB.nii.gz
sub_R2s_warped_2_MB=${sub2template_transfo_MB}_R2s_warped_2_MB.nii.gz

# FOR voxel-based analysis

#T1map
antsApplyTransforms -d 3 -i $sub_T1map \
-o ${sub_T1map_warped_2_MB} \
-r $template_T1map_MB  \
-t ${sub2template_transfo_MB}0Warp.nii.gz \
-t ${sub2template_transfo_WB}1Warp.nii.gz -t ${sub2template_transfo_WB}0GenericAffine.mat \
-v 1
#QSM
antsApplyTransforms -d 3 -i $sub_QSM \
-o ${sub_QSM_warped_2_MB} \
-r $template_T1map_MB  \
-t ${sub2template_transfo_MB}0Warp.nii.gz \
-t ${sub2template_transfo_WB}1Warp.nii.gz -t ${sub2template_transfo_WB}0GenericAffine.mat \
-v 1
#R2s
antsApplyTransforms -d 3 -i $sub_R2s \
-o ${sub_R2s_warped_2_MB} \
-r $template_T1map_MB  \
-t ${sub2template_transfo_MB}0Warp.nii.gz \
-t ${sub2template_transfo_WB}1Warp.nii.gz -t ${sub2template_transfo_WB}0GenericAffine.mat \
-v 1

# FOR region-based analysis
#Parc5Lab
antsApplyTransforms -d 3 -i ${atlas_parc_LR_5lab_MB} \
-o ${atlas_parc_LR_5lab_2_sub} \
-r $sub_T1map    \
-t [${sub2template_transfo_WB}0GenericAffine.mat,1] \
-t ${sub2template_transfo_WB}1InverseWarp.nii.gz \
-t ${sub2template_transfo_MB}0InverseWarp.nii.gz \
-n MultiLabel \
-v 1




