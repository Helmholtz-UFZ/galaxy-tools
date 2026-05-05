#' Filter ToxCast results to DNT-IVB assays
#'
#' Returns only rows matching the OECD DNT-IVB (OECD 377) assay component names
#' from a ToxCast-like CSV export.
#'
#' @param toxcast_file Character. Path to a ToxCast results CSV file.
#'
#' @return A data.frame with rows restricted to DNT-IVB assay components.
#'
#' @examples
#' \dontrun{
#' dnt <- dnt_ivb_assays("/path/to/toxcast_results.csv")
#' }
#'
#' @keywords internal
dnt_ivb_assays <- function(toxcast_file) {
  # assay component names DNT-IVB (OECD 377)
  assay_component_names <- c(
    "UKN5_HCS_SBAD2_neurite_outgrowth",
    "UKN5_HCS_SBAD2_cell_viability",
    "UKN2_HCS_IMR90_neural_migration",
    "UKN2_HCS_IMR90_cell_viability",
    "UKN4_HCS_LUHMES_neurite_outgrowth",
    "UKN4_HCS_LUHMES_cell_viability",
    "IUF_NPC1a_proliferation_BrdU_72hr",
    "IUF_NPC1b_proliferation_area_72hr",
    "IUF_NPC1_viability_72hr",
    "IUF_NPC1_cytotoxicity_72hr",
    "IUF_NPC2a_radial_glia_migration_72hr",
    "IUF_NPC2a_radial_glia_migration_120hr",
    "IUF_NPC2b_neuronal_migration_120hr",
    "IUF_NPC2c_oligodendrocyte_migration_120hr",
    "IUF_NPC3_neuronal_differentiation_120hr",
    "IUF_NPC4_neurite_length_120hr",
    "IUF_NPC4_neurite_area_120hr",
    "IUF_NPC5_oligodendrocyte_differentiation_120hr",
    "IUF_NPC2-5_cytotoxicity_72hr",
    "IUF_NPC2-5_cytotoxicity_120hr",
    "IUF_NPC2-5_cell_number_120hr",
    "IUF-NPC2-5_viability_120hr",
    "CCTE_Mundy_HCI_hNP1_Casp3_7",
    "CCTE_Mundy_HCI_hNP1_CellTiter",
    "CCTE_Mundy_HCI_hNP1_Pro_ObjectCount",
    "CCTE_Mundy_HCI_hNP1_Pro_ResponderAvgInten",
    "CCTE_Mundy_HCI_hNP1_Pro_MeanAvgInten",
    "CCTE_Mundy_HCI_Cortical_NOG_NeuronCount",
    "CCTE_Mundy_HCI_Cortical_NOG_NeuriteLength",
    "CCTE_Mundy_HCI_Cortical_NOG_NeuriteCount",
    "CCTE_Mundy_HCI_Cortical_NOG_BPCount",
    "CCTE_Mundy_HCI_Cortical_Synap&Neur_Matur_NeuronCount",
    "CCTE_Mundy_HCI_Cortical_Synap&Neur_Matur_NeuriteLength",
    "CCTE_Mundy_HCI_Cortical_Synap&Neur_Matur_NeuriteCount",
    "CCTE_Mundy_HCI_Cortical_Synap&Neur_Matur_BPCount",
    "CCTE_Mundy_HCI_Cortical_Synap&Neur_Matur_SynapseCount",
    "CCTE_Mundy_HCI_Cortical_Synap&Neur_Matur_CellBodySpotCount",
    "CCTE_Mundy_HCI_Cortical_Synap&Neur_Matur_NeuriteSpotCountPerNeuron",
    "CCTE_Mundy_HCI_Cortical_Synap&Neur_Matur_NeuriteSpotCountPerNeuriteLength",
    "CCTE_Mundy_HCI_CDI_NOG_BPCount",
    "CCTE_Mundy_HCI_CDI_NOG_NeuriteCount",
    "CCTE_Mundy_HCI_CDI_NOG_NeuriteLength",
    "CCTE_Mundy_HCI_CDI_NOG_NeuronCount",
    "CCTE_Mundy_HCI_hN2_NOG_NeuronCount",
    "CCTE_Mundy_HCI_hN2_NOG_NeuriteLength",
    "CCTE_Mundy_HCI_hN2_NOG_NeuriteCount",
    "CCTE_Mundy_HCI_hN2_NOG_BPCount",
    "CCTE_Shafer_MEA_dev_firing_rate_mean",
    "CCTE_Shafer_MEA_dev_burst_rate",
    "CCTE_Shafer_MEA_dev_active_electrodes_number",
    "CCTE_Shafer_MEA_dev_bursting_electrodes_number",
    "CCTE_Shafer_MEA_dev_per_burst_interspike_interval",
    "CCTE_Shafer_MEA_dev_per_burst_spike_percent",
    "CCTE_Shafer_MEA_dev_burst_duration_mean",
    "CCTE_Shafer_MEA_dev_interburst_interval_mean",
    "CCTE_Shafer_MEA_dev_network_spike_number",
    "CCTE_Shafer_MEA_dev_network_spike_peak",
    "CCTE_Shafer_MEA_dev_spike_duration_mean",
    "CCTE_Shafer_MEA_dev_network_spike_duration_std",
    "CCTE_Shafer_MEA_dev_inter_network_spike_interval_mean",
    "CCTE_Shafer_MEA_dev_per_network_spike_spike_number_mean",
    "CCTE_Shafer_MEA_dev_per_network_spike_spike_percent",
    "CCTE_Shafer_MEA_dev_correlation_coefficient_mean",
    "CCTE_Shafer_MEA_dev_mutual_information_norm",
    "CCTE_Shafer_MEA_dev_LDH",
    "CCTE_Shafer_MEA_dev_AB",
    "CCTE_Shafer_MEA_dev_burst_rate_DIV12",
    "CCTE_Shafer_MEA_dev_interburst_interval_mean_DIV12",
    "CCTE_Shafer_MEA_dev_burst_duration_mean_DIV12",
    "CCTE_Shafer_MEA_dev_per_burst_interspike_interval_DIV12",
    "CCTE_Shafer_MEA_dev_firing_rate_mean_DIV12",
    "CCTE_Shafer_MEA_dev_mutual_information_norm_DIV12",
    "CCTE_Shafer_MEA_dev_bursting_electrodes_number_DIV12",
    "CCTE_Shafer_MEA_dev_active_electrodes_number_DIV12",
    "CCTE_Shafer_MEA_dev_spike_duration_mean_DIV12",
    "CCTE_Shafer_MEA_dev_network_spike_duration_std_DIV12",
    "CCTE_Shafer_MEA_dev_inter_network_spike_interval_mean_DIV12",
    "CCTE_Shafer_MEA_dev_per_network_spike_spike_number_mean_DIV12",
    "CCTE_Shafer_MEA_dev_network_spike_number_DIV12",
    "CCTE_Shafer_MEA_dev_network_spike_peak_DIV12",
    "CCTE_Shafer_MEA_dev_per_network_spike_spike_percent_DIV12",
    "CCTE_Shafer_MEA_dev_per_burst_spike_percent_DIV12",
    "CCTE_Shafer_MEA_dev_correlation_coefficient_mean_DIV12"
  )

  data <- as.data.frame(data.table::fread(toxcast_file))
  data <- data %>%
    filter(NAME %in% assay_component_names)

  return(data)

}
