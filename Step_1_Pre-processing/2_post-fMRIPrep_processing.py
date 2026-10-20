import os
import glob
import pandas as pd
from scipy.stats import zscore
import nibabel as nib
from nilearn.maskers import NiftiMasker
from nilearn import image
import argparse

# Load a resampled, binarised GM mask
def mask_img_load(folder, img):
    img_path = os.path.join(folder, img)
    mask = nib.load(img_path)
    return mask

# Load an image from a single brain:
def img_load(folder, img):
    img_path = os.path.join(folder, img)
    fmri_image = nib.load(img_path)
    return fmri_image

# Extract the timeseries from a single session
def extract_time_series(fmri_image, mask, confounds):
    brain_masker = NiftiMasker(mask, standardize_confounds=True, memory=None)
    brain_time_series = brain_masker.fit_transform(fmri_image, confounds=confounds)
    return brain_time_series, brain_masker

# Transform the FC or DC array back into a NIfTI volume and save
def array_to_nifti(brain_masker, array):
    img = brain_masker.inverse_transform(array)
    return img

# To perform the additional de-noising
def remove_confounds(fMRIroot, CONFOUNDlist):
	# create a list of session folders
	# construct the pattern to match directories starting with 'sub-'
	pattern = os.path.join(fMRIroot, 'sub-*')
	# use glob to find directories matching the pattern
	ses_list = sorted(glob.glob(pattern))
	
	for sesh in ses_list:
		try:
			ses = os.path.basename(sesh)
			print("Working on " + ses + ".")
			ses_folder = os.path.join(fMRIroot, ses, ses, 'func')
			
			# load the GM mask
			mask_suffix = "_task-rest_space-MNI152NLin6Asym_res-2_desc-brain_mask.nii.gz"
			GMmask = ses + mask_suffix
			gm_mask = mask_img_load(ses_folder, GMmask)
			print("GM mask loaded.")
		
			# load an image from a single brain:
			fmri_image_suffix = "_task-rest_space-MNI152NLin6Asym_desc-smoothAROMAnonaggr_bold.nii.gz"
			fmri_image_filename = ses + fmri_image_suffix
			fmri_image_pre = img_load(ses_folder, fmri_image_filename)
			# remove the first 10 volumes
			fmri_image = image.index_img(fmri_image_pre, slice(10, fmri_image_pre.shape[-1]))
			print("The image dimensions are: " + str(fmri_image.shape))
			
			# load confounds
			confounds_suffix = "_task-rest_desc-confounds_timeseries.tsv"
			CONFOUNDtsv = ses + confounds_suffix
			confoundPATH = os.path.join(ses_folder, CONFOUNDtsv)
			confounds_all = pd.read_csv(confoundPATH, sep='\t')
			confounds_pre = confounds_all[CONFOUNDlist]
			confounds = confounds_pre.iloc[10:]
			print("Confounds loaded.")
			
			# create a NiftiMasker object and extract the time series
			brain_time_series, brain_masker = extract_time_series(fmri_image, gm_mask, confounds)
			print("De-noised time series extracted.")
			
			# Standardize the time series
			brain_time_series_standardized = zscore(brain_time_series, axis=0)
			print("Time series standardized.")
			
			# convert the fully de-noised data and save it as a NIfTI image
			denoised_img = array_to_nifti(brain_masker, brain_time_series_standardized)
			denoised_img_name = ses + "_denoised.nii.gz"
			output_filename = os.path.join(ses_folder, denoised_img_name)
			nib.save(denoised_img, output_filename# , gzip=True
			)
			print("De-noised time series of " + ses + " saved.")
			
		except FileNotFoundError as fnf_error:
			print(f"File not found: {fnf_error}")
		except PermissionError as perm_error:
			print(f"Permission denied: {perm_error}")
		except Exception as e:
			print(f"An error occurred while processing {sesh}: {e}")
			
	print("Done!")

def main():
	parser = argparse.ArgumentParser(description="Additional de-noising of fMRI data.")
	parser.add_argument("fMRIroot", help="Root directory containing the fMRI data")
	parser.add_argument("CONFOUNDlist", nargs='+', help="List of confounds to remove")

	args = parser.parse_args()
	remove_confounds(args.fMRIroot, args.CONFOUNDlist)

if __name__ == "__main__":
	main()
