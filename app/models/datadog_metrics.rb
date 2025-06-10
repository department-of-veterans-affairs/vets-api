# frozen_string_literal: true

DATADOG_METRIC_ALLOWLIST = [
  # MR list calls
  'labs_and_tests_list',
  'care_summaries_and_notes_list',
  'vaccines_list',
  'allergies_list',
  'health_conditions_list',
  'vitals_list',
  # MR detail calls
  'labs_and_tests_details',
  'radiology_images_list',
  'care_summaries_and_notes_details',
  'vaccines_details',
  'allergies_details',
  'health_conditions_details',
  'vitals_details',
  # MR download calls
  'download_blue_button',
  'download_ccd',
  'download_sei'
].freeze
