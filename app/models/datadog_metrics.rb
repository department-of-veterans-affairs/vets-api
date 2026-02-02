# frozen_string_literal: true

module DatadogMetrics
  ALLOWLIST = [
    # MR list calls
    'mr.labs_and_tests_list',
    'mr.imaging_results_list',
    'mr.care_summaries_and_notes_list',
    'mr.vaccines_list',
    'mr.allergies_list',
    'mr.health_conditions_list',
    'mr.vitals_list',
    # MR detail calls
    'mr.labs_and_tests_details',
    'mr.imaging_results_details',
    'mr.radiology_images_list',
    'mr.care_summaries_and_notes_details',
    'mr.vaccines_details',
    'mr.allergies_details',
    'mr.health_conditions_details',
    'mr.vitals_details',
    # MR download calls
    'mr.download_blue_button',
    'mr.download_ccd',
    'mr.download_sei'
  ].freeze
end
