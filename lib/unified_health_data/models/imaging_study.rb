# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class ImagingStudy
    include Vets::Model

    attribute :id, String
    attribute :identifier, String # The full FHIR identifier value
    attribute :status, String
    attribute :modality, String # Primary modality code (e.g., 'ECG', 'CT')
    attribute :date, String # Pass on as-is to the frontend (from started)
    attribute :sort_date, String # Normalized date for sorting (internal use only)
    attribute :description, String
    attribute :notes, String, array: true
    attribute :patient_id, String
    attribute :series_count, Integer
    attribute :image_count, Integer
    attribute :series, Array # Array of series info for potential image retrieval
    attribute :dicom_zip_url, String # Presigned S3 URL for DICOM zip download (study-level)

    default_sort_by sort_date: :desc
  end
end
