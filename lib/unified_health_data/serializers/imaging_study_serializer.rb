# frozen_string_literal: true

module UnifiedHealthData
  module Serializers
    class ImagingStudySerializer
      include JSONAPI::Serializer

      set_id :id
      set_type :imaging_study

      attributes :id,
                 :identifier,
                 :status,
                 :modality,
                 :date,
                 :description,
                 :notes,
                 :patient_id,
                 :series_count,
                 :image_count,
                 :series,
                 :dicom_zip_url
    end
  end
end
