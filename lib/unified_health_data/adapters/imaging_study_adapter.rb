# frozen_string_literal: true

require_relative '../models/imaging_study'
require_relative 'date_normalizer'

module UnifiedHealthData
  module Adapters
    class ImagingStudyAdapter
      include DateNormalizer

      # Parses imaging study records from FHIR ImagingStudy resources
      #
      # @param records [Array<Hash>] Array of FHIR entry records, optionally tagged with 'source'
      # @return [Array<UnifiedHealthData::ImagingStudy>] Array of parsed imaging study objects
      def parse(records)
        return [] if records.blank?

        filtered = records.select do |entry|
          entry.dig('resource', 'resourceType') == 'ImagingStudy'
        end

        parsed = filtered.map { |record| parse_single_study(record) }
        parsed.compact
      end

      # Parses a single imaging study record from a FHIR ImagingStudy resource
      #
      # @param record [Hash] A single FHIR entry record
      # @return [UnifiedHealthData::ImagingStudy, nil] Parsed imaging study object or nil if invalid
      def parse_single_study(record)
        return nil if record.nil? || record['resource'].nil?

        resource = record['resource']
        return nil unless resource['resourceType'] == 'ImagingStudy'

        date_value = resource['started']
        series_data = resource['series'] || []

        UnifiedHealthData::ImagingStudy.new(
          id: resource['id'],
          identifier: extract_identifier(resource),
          status: resource['status'],
          modality: extract_primary_modality(resource),
          date: date_value,
          sort_date: normalize_date_for_sorting(date_value),
          description: resource['description'],
          notes: extract_notes(resource),
          patient_id: extract_patient_id(resource),
          series_count: resource['numberOfSeries'] || series_data.size,
          image_count: resource['numberOfInstances'] || count_images(series_data),
          series: parse_series(series_data),
          dicom_zip_url: extract_presigned_url(resource)
        )
      end

      private

      # Extracts a presigned URL from the extensions of any FHIR element
      # (study-level for DICOM zip, instance-level for thumbnails).
      #
      # @param element [Hash] A FHIR element (resource or instance) with an extensions array
      # @return [String, nil] the presigned URL or nil
      def extract_presigned_url(element)
        extensions = element['extension'] || []
        url_extension = extensions.find do |ext|
          ext['url'] == 'http://va.gov/mhv/fhir/StructureDefinition/presigned-url'
        end
        url_extension&.dig('valueUrl')
      end

      # Extracts the primary identifier value
      #
      # @param resource [Hash] FHIR ImagingStudy resource
      # @return [String, nil] the identifier value or nil
      def extract_identifier(resource)
        identifiers = resource['identifier'] || []
        usual_identifier = identifiers.find { |id| id['use'] == 'usual' }
        usual_identifier&.dig('value') || identifiers.first&.dig('value')
      end

      # Extracts the primary modality code from study-level or first series
      #
      # @param resource [Hash] FHIR ImagingStudy resource
      # @return [String, nil] the modality code or nil
      def extract_primary_modality(resource)
        # First check study-level modality
        study_modality = resource.dig('modality', 0, 'code')
        return study_modality if study_modality.present?

        # Fall back to first series modality
        resource.dig('series', 0, 'modality', 'code')
      end

      # Extracts notes from the note array
      #
      # @param resource [Hash] FHIR ImagingStudy resource
      # @return [Array<String>] array of note texts
      def extract_notes(resource)
        notes = resource['note'] || []
        notes.map { |note| note['text'] }.compact
      end

      # Extracts the patient ID from the subject reference
      #
      # @param resource [Hash] FHIR ImagingStudy resource
      # @return [String, nil] the patient ID or nil
      def extract_patient_id(resource)
        reference = resource.dig('subject', 'reference')
        return nil unless reference

        # Extract ID from "Patient/1234567890V012345" format
        reference.split('/').last
      end

      # Counts total images across all series
      #
      # @param series_data [Array] Array of series from the resource
      # @return [Integer] total number of images
      def count_images(series_data)
        series_data.sum { |series| (series['instance'] || []).size }
      end

      # Parses series data for potential image retrieval
      #
      # @param series_data [Array] Array of series from the resource
      # @return [Array<Hash>] parsed series info
      def parse_series(series_data)
        series_data.map do |series|
          {
            uid: series['uid'],
            number: series['number'],
            modality: series.dig('modality', 'code'),
            instances: parse_instances(series['instance'] || [])
          }
        end
      end

      # Parses instance data within a series
      #
      # @param instances [Array] Array of instances from a series
      # @return [Array<Hash>] parsed instance info
      def parse_instances(instances)
        instances.map do |instance|
          {
            uid: instance['uid'],
            number: instance['number'],
            title: instance['title'],
            sop_class: instance.dig('sopClass', 'code'),
            image_id: extract_image_id(instance),
            thumbnail_url: extract_presigned_url(instance)
          }
        end
      end

      # Extracts the VA image ID from instance extension
      #
      # @param instance [Hash] Instance data
      # @return [String, nil] the image ID or nil
      def extract_image_id(instance)
        extensions = instance['extension'] || []
        image_extension = extensions.find do |ext|
          ext['url'] == 'http://hl7.org/fhir/StructureDefinition/imagingstudy-instance-uid'
        end
        image_extension&.dig('valueString')
      end
    end
  end
end
