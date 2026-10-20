# Load required libraries
library(tidyverse)    # For data manipulation and visualization
library(neurobase)    # Neuroimaging utilities
library(readr)        # For reading CSV files
library(furrr)        # For parallel processing
library(lme4)         # For running linear mixed models
library(lmerTest)     # For running linear mixed models
library(pTFCE)        # For statistical analysis on neuroimaging data
library(future)       # For parallel processing
library(conflicted)   # For handling package conflicts

options(future.globals.maxSize = 5 * 1024^3)  # Set to 5 GB

# Set working directory
setwd('/data/project/PSILAUT/wDC/Output/Stats/Voxel-wise/Main/')

# List all files in the directory
all_files <- list.files()

# Filter files matching the pattern
subj_list <- all_files[grep("^sub-ps....._denoised_3mm_wDC_Z\\.nii\\.gz$", all_files)]

# Check if any files were found
if (length(subj_list) == 0) {
 stop("Error: No files matching the pattern 'sub-ps....._denoised_3mm_wDC_Z.nii.gz' found.")
}
print(paste("Found", length(subj_list), "files matching the pattern."))

# Setup future plan to use multicore
plan(multicore, workers = 16)  # Adjust number of workers to match --cpus-per-task
print("Future plan set up for multicore processing.")

# Function to process each subject
process_subject <- function(subj_file) {
    subj_id <- tools::file_path_sans_ext(basename(subj_file))  # Extract subject ID
    print(paste("Processing subject:", subj_id))
    wDC <- readnii(subj_file)  # Read the NIfTI file
    print(dim(wDC))  # Print the dimensions of the wDC image
    
    wDC_df_T <- as.data.frame(t(data.frame(wDC = c(wDC))))  # Transpose the flattened data
    print(dim(wDC_df_T)) # Print the dimensions of the wDC vector
    colnames(wDC_df_T) <- sprintf("V%s", seq_len(ncol(wDC_df_T)))
    rownames(wDC_df_T) <- subj_id

    rm(wDC)  # Free memory
    gc()  # Run garbage collection
    
    return(wDC_df_T)
}

# Apply the function in parallel to all subjects
# Process each subject and collect results in parallel
df_list <- future_map(subj_list, function(subj_file) {
    result <- process_subject(subj_file)
    gc()  # Run garbage collection after processing each subject
    return(result)
}, .progress = TRUE)
print("Processed all subjects in parallel.")
gc()

# Combine all data frames into the final dataframe
final_df <- do.call(rbind, df_list)
print("Combined all data frames into final dataframe.")

# Clear unnecessary variables
rm(df_list)
gc()
print("Cleared unnecessary variables.")

# Read the IV/covariate dataframe from a CSV file
df_iv_cov <- read.csv("/data/project/PSILAUT/wDC/Output/Stats/Voxel-wise/Main/Demographics.csv")
print("Read IV/covariate dataframe from CSV file.")
print(head(df_iv_cov))  # Print the first few rows of df_iv_cov
print(summary(df_iv_cov))  # Print a summary of df_iv_cov

# Check dimensions of final_df and df_iv_cov
print("Dimensions of final_df:")
print(dim(final_df))
print("Dimensions of df_iv_cov:")
print(dim(df_iv_cov))

# Combine the final_df and IV/covariate dataframe
ult_df <- cbind(final_df, df_iv_cov)
ult_df[["group"]] <- as.factor(ult_df[["group"]])
ult_df[["drug"]] <- as.factor(ult_df[["drug"]])
ult_df[["id"]] <- as.factor(ult_df[["id"]])
print("Combined final_df and df_iv_cov.")
print("Checking combined dataframe for NA values:")
na_count <- sum(is.na(ult_df))
print(paste("Total NA values:", na_count))
if (na_count > 0) {
  na_columns <- colnames(ult_df)[colSums(is.na(ult_df)) > 0]
  print("Columns with NA values:")
  print(na_columns)
}

# Create a vector of target voxel names
target_voxels <- sprintf("V%s", seq_len(ncol(final_df)))

# Clear final_df to save memory
rm(final_df, df_iv_cov)
gc()
print("Cleared final_df to save memory.")

# Function to fit the LMM
fit_lmm <- function(target_voxel, index) {
  if (all(ult_df[[target_voxel]] == 0)) {
    print(paste("Only NA for voxel:", target_voxel))
    return(NULL)
  } else {
    print(paste("Fitting linear mixed model for voxel:", target_voxel))
    tryCatch({
      model <- lmerTest::lmer(formula = as.formula(paste(target_voxel, "~ group * drug + (1|id)")), data = ult_df)
      print(summary(model))  # Print model summary
      return(list(index = index, model = model))
    }, error = function(e) {
      print(paste("Error fitting model for voxel:", target_voxel, ":", e$message))
      return(NULL)
    })
  }
}

# Apply the function in parallel to each target voxel
lmm_results <- future_map(seq_along(target_voxels), ~fit_lmm(target_voxels[.x], .x), .progress = TRUE)
print("Fitted LMM in parallel for each target voxel.")

# Run garbage collection after fitting the models
gc()

# Define a function to extract results or return default values
extract_results_or_default <- function(model_results, term, index) {
  if (is.null(model_results[[index]])) {
    return(c(statistic = 0, p_value = 0, dof = 0))
  } else {
    stat_value <- summary(model_results[[index]]$model)$coef[term, "t value"]
    p_value <- summary(model_results[[index]]$model)$coef[term, "Pr(>|t|)"]
    dof <- summary(model_results[[index]]$model, ddf = "Satterthwaite")$coef[term, "df"]
    return(c(statistic = stat_value, p_value = p_value, dof = dof))
  }
}

# Extract results for each term
terms <- c("drug2", "drug5", "group1", "group1:drug2", "group1:drug5")
results_list <- lapply(terms, function(term) {
  purrr::map(seq_along(lmm_results), function(i) {
    #print(paste("Processing index:", i))
    extract_results_or_default(lmm_results, term, i)
  })
})

# Clear intermediate variables and run garbage collection
rm(lmm_results)
gc()

# Create data frames for the statistics and p-values
result_dfs <- lapply(results_list, function(res) data.frame(do.call(rbind, res)))

# Write results to CSV
write.csv(result_dfs[[1]], "drug2_results.csv", row.names = FALSE)
write.csv(result_dfs[[2]], "drug5_results.csv", row.names = FALSE)
write.csv(result_dfs[[3]], "group1_results.csv", row.names = FALSE)
write.csv(result_dfs[[4]], "group1:drug2_results.csv", row.names = FALSE)
write.csv(result_dfs[[5]], "group1:drug5_results.csv", row.names = FALSE)

# Define path to the NIfTI file, set the df variables and the output file names
target_nifti_file <- subj_list[1]
drug2_df <- result_dfs[[1]]
drug5_df <- result_dfs[[2]]
group1_df <-result_dfs[[3]]
group1_drug2_df <- result_dfs[[4]]
group1_drug5_df <- result_dfs[[5]]
output_files <- c("drug2_t_map", "drug5_t_map", "group1_t_map", "group1:drug2_t_map", "group1:drug5_t_map")

convert_and_save_nifti <- function(target_nifti_file, output_files, drug2_df, drug5_df, group1_df, group1_drug2_df, group1_drug5_df) {
  # Read the target NIfTI file
  target_image <- readnii(target_nifti_file)
  
  # Convert the first column of each dataframe to NIfTI array
  drug2_nifti <- niftiarr(target_image, drug2_df$statistic)
  drug5_nifti <- niftiarr(target_image, drug5_df$statistic)
  group1_nifti <- niftiarr(target_image, group1_df$statistic)
  group1_drug2_nifti <- niftiarr(target_image, group1_drug2_df$statistic)
  group1_drug5_nifti <- niftiarr(target_image, group1_drug5_df$statistic)
  # Alternatively, https://neuroconductor.org/help/neurobase/reference/remake_img.html
  
  # Save the NIfTI files
  writenii(drug2_nifti, output_files[1])
  writenii(drug5_nifti, output_files[2])
  writenii(group1_nifti, output_files[3])
  writenii(group1_drug2_nifti, output_files[4])
  writenii(group1_drug5_nifti, output_files[5])
}

# Usage
convert_and_save_nifti(target_nifti_file, output_files, drug2_df, drug5_df, group1_df, group1_drug2_df, group1_drug5_df)

# Function to process NIfTI files for pTFCE analysis
process_nifti <- function(stat_name, result_df) {
  Tmap <- readNIfTI(paste0(stat_name, "_t_map.nii.gz"))
  degrees_of_freedom <- median(result_df[result_df$dof != 0, ]$dof)
  Z <- qnorm(pt(Tmap, df = degrees_of_freedom, log.p = TRUE), log.p = TRUE)
  
  pTFCE <- ptfce(Z, MASK)

  # Save Z and pTFCE maps
  writeNIfTI(Z, paste0(stat_name, "_original-z-score-map"))
  writeNIfTI(pTFCE$Z, paste0(stat_name, "_pTFCE-z-score-map"))

  # Save p-values
  writeNIfTI(pTFCE$p, paste0(stat_name, "_pTFCE-p-value-map"))
}

# Define paths to the NIfTI file and output file names
output_files <- c("drug2", "drug5", "group1", "group1:drug2", "group1:drug5")

# Mask for pTFCE
MASK <- readNIfTI("binary_GM_Mask_3mm.nii.gz")

# Process each statistic
lapply(output_files, function(stat_name) {
  process_nifti(stat_name, result_dfs[[which(output_files == stat_name)]])
})

print("Finished pTFCE processing.")

