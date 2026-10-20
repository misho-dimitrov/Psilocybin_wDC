import csv
import sys
import os
from img_load import img_load
from mask_img_load import mask_img_load
from extract_time_series import extract_time_series
from cos_sim_func import cos_sim_func
from thresh_mat import thresh_mat
from calc_dc import calc_dc
from z_score_dc import z_score_dc
from array_to_nifti import array_to_nifti
import nibabel as nib
import pickle
import gc


# To calculate functional connectivity and degree centrality from an adjacency matrix
def calc_dc_auto(fMRI_image_path, mask_image_path):
    """ Calculate functional connectivity and degree centrality from an adjacency matrix and save the DC images to disk.
    
    Args:
        fMRI_image_path (string): fMRI image path.
        mask_image_path (string): Mask image path.
        
    """
    
    # load the BOLD image
    fmri_image = img_load(fMRI_image_path)
    image_name_full = os.path.basename(fMRI_image_path)
    # Extract image name, handling .nii.gz extension
    if image_name_full.endswith(".nii.gz"):
        image_name = image_name_full[:-7]  # Removes ".nii.gz"
    else:
        image_name = os.path.splitext(image_name_full)[0]  # Handles other cases
    print(f"Processing {image_name}")
    print("The image dimensions are: " + str(fmri_image.shape))
        
    # load the GM mask
    gm_mask = mask_img_load(mask_image_path)
    print("GM mask loaded.")
        
    # create a NiftiMasker object and extract the time series
    brain_time_series, brain_masker = extract_time_series(fmri_image, gm_mask)
    print("Time series extracted.")
    
    # Free up memory
    del fmri_image, gm_mask
    gc.collect()
        
    # calculate the correlations between each pair of voxels
    cos_sim = cos_sim_func(brain_time_series)
    print("Correlations calculated.")
    
    # Free up memory
    del brain_time_series
    gc.collect()
        
    # threshold the matrix
    adjacency_matrix = thresh_mat(cos_sim)
    print("Adjacency matrix thresholded.")
    
    # Free up memory
    del cos_sim
    gc.collect()
        
    # calculate the degree centrality (DC)
    dc = calc_dc(adjacency_matrix)
    print("Raw wDC values calcualted.")
    
    # Free up memory
    del adjacency_matrix
    gc.collect()
        
    # convert the raw DC matrix and save it as a NIfTI image
    dc_img = array_to_nifti(brain_masker,dc)
    dc_img_name = os.path.join("/data/project/PSILAUT/wDC/Output/", image_name + "_wDC_raw.nii.gz")
    nib.save(dc_img, dc_img_name)
    print(f"Raw wDC image of {image_name} saved.")
    
    # z-score the wDC matrix and save it as a NIfTI image
    z_scored_dc = z_score_dc(dc)
    print("DC matrix z-scored.")
    z_scored_dc_img = array_to_nifti(brain_masker, z_scored_dc)
    z_scored_dc_img_name = os.path.join("/data/project/PSILAUT/wDC/Output/", image_name + "_wDC_Z.nii.gz")
    nib.save(z_scored_dc_img, z_scored_dc_img_name)
    print(f"Z-scored wDC image of {image_name} saved.")
        
    print("Done!")

if __name__ == "__main__":
    fMRI_image_path = sys.argv[1]
    mask_image_path = sys.argv[2]

    calc_dc_auto(fMRI_image_path, mask_image_path)


