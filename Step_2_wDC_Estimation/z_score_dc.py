import sys
import numpy as np
from sklearn.preprocessing import StandardScaler

# Z-score
def z_score_dc(dc_array):
    dc = dc_array.flatten()  # Flatten to apply the mask easily
    # Create a mask for positive values (voxels with values of 0 are missing signal for this particular session but are part of the common mask)
    positive_mask = dc > 0
    
    # Reshape positive values into 2D for StandardScaler
    positive_dc = dc[positive_mask].reshape(-1, 1)
    
    # Apply StandardScaler only to the positive values
    scaler = StandardScaler()
    
    # Scale the positive values
    scaled_positive_dc_2D = scaler.fit_transform(positive_dc)
    
    # Flatten the result
    scaled_positive_dc = scaled_positive_dc_2D.flatten()
    
    # Initialize an array to hold the scaled values
    dc_scaled = np.zeros_like(dc)
    
    # Replace the positive values with their scaled counterparts
    dc_scaled[positive_mask] = scaled_positive_dc
    
    # Reshape dc_scaled back into the original shape of dc_array
    return dc_scaled.reshape(dc_array.shape)

if __name__ == "__main__":
    dc_array = sys.argv[1]
    z_score_dc(dc_array)


