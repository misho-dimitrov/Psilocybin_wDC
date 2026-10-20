import sys
import nibabel as nib

# Load my resampled GM mask
def mask_img_load(img_path):
    """Load a brain mask image.
    
    The function returns a brain mask image as a nibabel image object.
    
    Args:
        img_path (string): Mask image path.
        
    Returns:
        mask (nibabel.nifti1.Nifti1Image:): Mask image.
        
    """
    
    mask = nib.load(img_path)
    return mask

if __name__ == "__main__":
    img_path = sys.argv[1]
    mask_img_load(img_path)



