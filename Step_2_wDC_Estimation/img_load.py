import sys
import nibabel as nib


# Load an image from a single brain:
def img_load(img_path):
    """Load an image from a single brain.
    
    The function returns a brain image as a nibabel image object.
    
    Args:
        img_path (string): Image path.
        
    Returns:
        fmri_image (nibabel.nifti1.Nifti1Image:): Brain image.
        
    """
    
    fmri_image = nib.load(img_path)
    return fmri_image

if __name__ == "__main__":
    img_path = sys.argv[1]
    img_load(img_path)
