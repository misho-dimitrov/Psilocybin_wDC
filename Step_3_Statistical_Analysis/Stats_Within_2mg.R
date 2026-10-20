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

# Set preference for dplyr::filter to avoid conflict
conflicts_prefer(dplyr::filter)

# Set working directory
setwd('/data/project/PSILAUT/wDC/Output/Stats/Voxel-wise/Within_2mg/')

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
df_iv_cov <- read.csv("/data/project/PSILAUT/wDC/Output/Stats/Voxel-wise/Within_2mg/Demographics_2mg.csv")
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

# Split ult_df into two dataframes based on group
ult_df_group0 <- ult_df %>% filter(group == 0)
#ult_df_group1 <- ult_df %>% filter(group == 1)

# Create a vector of target voxel names based on mask
target_voxels <- sprintf("V%s", seq_len(ncol(final_df)))

# Clear final_df to save memory
rm(final_df, df_iv_cov, ult_df)
gc()
print("Cleared final_df to save memory.")

# Function to fit the LMM for group 0
fit_lmm_group0 <- function(target_voxel, index) {
  if (all(ult_df_group0[[target_voxel]] == 0)) {
    print(paste("Only NA for voxel:", target_voxel, "in group 0"))
    return(NULL)
  } else {
    print(paste("Fitting linear mixed model for voxel:", target_voxel, "in group 0"))
    tryCatch({
      model <- lmerTest::lmer(formula = as.formula(paste(target_voxel, "~ drug + (1|id)")), data = ult_df_group0)
      print(summary(model))  # Print model summary
      return(list(index = index, model = model))
    }, error = function(e) {
      print(paste("Error fitting model for voxel:", target_voxel, "in group 0:", e$message))
      return(NULL)
    })
  }
}

# Function to fit the LMM for group 1
#fit_lmm_group1 <- function(target_voxel, index) {
#  if (all(ult_df_group1[[target_voxel]] == 0)) {
#    print(paste("Only NA for voxel:", target_voxel, "in group 1"))
#    return(NULL)
#  } else {
#    print(paste("Fitting linear mixed model for voxel:", target_voxel, "in group 1"))
#    tryCatch({
#      model <- lmerTest::lmer(formula = as.formula(paste(target_voxel, "~ drug + (1|id)")), data = ult_df_group1)
#      print(summary(model))  # Print model summary
#      return(list(index = index, model = model))
#    }, error = function(e) {
#      print(paste("Error fitting model for voxel:", target_voxel, "in group 1:", e$message))
#      return(NULL)
#    })
#  }
#}

# Apply the function in parallel to each target voxel for group 0
lmm_results_group0 <- future_map(seq_along(target_voxels), ~fit_lmm_group0(target_voxels[.x], .x), .progress = TRUE)
print("Fitted LMM in parallel for each target voxel in group 0.")

# Apply the function in parallel to each target voxel for group 1
#lmm_results_group1 <- future_map(seq_along(target_voxels), ~fit_lmm_group1(target_voxels[.x], .x), .progress = TRUE)
#print("Fitted LMM in parallel for each target voxel in group 1.")

# Run garbage collection after fitting the models
gc()

# Define a function to extract results or return default values
extract_results_or_default <- function(model_results, index) {
  if (is.null(model_results[[index]])) {
    return(c(statistic = 0, p_value = 0, dof = 0))
  } else {
    stat_value <- summary(model_results[[index]]$model)$coef["drug2", "t value"]
    p_value <- summary(model_results[[index]]$model)$coef["drug2", "Pr(>|t|)"]
    dof <- summary(model_results[[index]]$model, ddf = "Satterthwaite")$coef["drug2", "df"]
    return(c(statistic = stat_value, p_value = p_value, dof = dof))
  }
}

# Extract results for each target voxel for group 0
results_list_group0 <- purrr::map(seq_along(lmm_results_group0), function(i) {
  extract_results_or_default(lmm_results_group0, i)
})

# Extract results for each target voxel for group 1
#results_list_group1 <- purrr::map(seq_along(lmm_results_group1), function(i) {
#  extract_results_or_default(lmm_results_group1, i)
#})

# Clear intermediate variables and run garbage collection
rm(lmm_results_group0#, 
#lmm_results_group1
)
gc()

# Create data frames for the statistics and p-values for group 0
result_df_group0 <- data.frame(do.call(rbind, results_list_group0))

# Create data frames for the statistics and p-values for group 1
#result_df_group1 <- data.frame(do.call(rbind, results_list_group1))

# Write results to CSV for group 0
write.csv(result_df_group0, "within_NT_drug_2mg_results.csv", row.names = FALSE)

# Write results to CSV for group 1
#write.csv(result_df_group1, "within_A_drug_2mg_results.csv", row.names = FALSE)

# Function to convert t-values CSV to NIfTI
convert_csv_to_nifti <- function(result_df, output_file_name) {
  # Load the first NIfTI file as a template
  target_nifti_file <- subj_list[1]
  target_image <- readnii(target_nifti_file)
  print("Loaded first NIfTI file as template.")
  print(dim(target_image))
  print(summary(c(target_image)))
  
  # Convert the t-values to a NIfTI image and save
  nifti_image <- niftiarr(target_image, result_df$statistic)
  writenii(nifti_image, output_file_name)
  print(paste("Converted t-values to NIfTI and saved as", output_file_name))
}

# Convert each t-values CSV to NIfTI for group 0
convert_csv_to_nifti(result_df_group0, "within_NT_drug_2mg_t_map.nii.gz")

# Convert each t-values CSV to NIfTI for group 1
#convert_csv_to_nifti(result_df_group1, "within_A_drug_2mg_t_map.nii.gz")

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

# Define paths to the NIfTI file and output file names for both groups
output_files_group0 <- "within_NT_drug_2mg"
#output_files_group1 <- "within_A_drug_2mg"

# Mask for pTFCE
MASK <- readNIfTI("binary_GM_Mask_3mm.nii.gz")

# Process for group 0
process_nifti(output_files_group0, result_df_group0)

# Process for group 1
#process_nifti(output_files_group1, result_df_group1)

#print("Finished pTFCE processing for both groups.")
print("Finished pTFCE processing for the non-autistic group.")
#print("Finished pTFCE processing for the autistic group.")

