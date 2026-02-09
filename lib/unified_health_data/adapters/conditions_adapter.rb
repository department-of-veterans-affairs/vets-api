# frozen_string_literal: true

require_relative '../models/condition'
require_relative 'date_normalizer'

module UnifiedHealthData
  module Adapters
    class ConditionsAdapter
      include DateNormalizer
      def parse(records, filter_by_status: true)
        return [] if records.blank?

        filtered = records.select do |record|
          resource = record['resource']
          next false unless resource && resource['resourceType'] == 'Condition'
          next true unless filter_by_status

          should_include_condition?(resource)
        end
        parsed = filtered.map { |record| parse_single_condition(record, filter_by_status:) }
        parsed.compact
      end

      def parse_single_condition(record, filter_by_status: true)
        return nil if record.nil? || record['resource'].nil?

        resource = record['resource']
        date_value = resource['onsetDateTime'] || resource['recordedDate']

        # Filter out conditions without active clinical status if filtering is enabled
        return nil if filter_by_status && !should_include_condition?(resource)

        UnifiedHealthData::Condition.new(
          id: resource['id'],
          date: date_value,
          sort_date: normalize_date_for_sorting(date_value),
          name: resource.dig('code', 'coding', 0, 'display') || resource.dig('code', 'text') || '',
          provider: extract_condition_provider(resource),
          facility: extract_condition_facility(resource),
          comments: extract_condition_comments(resource)
        )
      end

      private

      # Determines if a condition should be included based on its clinical status
      # Only includes conditions with clinicalStatus of 'active'
      # Conditions with no clinicalStatus or non-active status (e.g., resolved) are excluded
      #
      # @param resource [Hash] FHIR Condition resource
      # @return [Boolean] true if the condition should be included (has active clinicalStatus)
      def should_include_condition?(resource)
        clinical_status = resource.dig('clinicalStatus', 'coding', 0, 'code')

        # Only include conditions with 'active' clinical status
        # This excludes conditions with nil/missing clinicalStatus or non-active statuses like 'resolved'
        clinical_status == 'active'
      end

      def extract_condition_comments(resource)
        return [] unless resource['note']

        if resource['note'].is_a?(Array)
          resource['note'].map { |note| note['text'] }.compact
        else
          [resource['note']['text']].compact
        end
      end

      def extract_condition_provider(resource)
        reference = resource.dig('recorder', 'reference')
        return '' unless reference && resource['contained']

        practitioner = find_contained_practitioner(resource, reference)
        return '' unless practitioner

        if practitioner['name'].is_a?(Array)
          name_obj = practitioner['name'].find { |n| n['text'] } || practitioner['name'].first
          name_obj['text'] || format_practitioner_name(name_obj) || ''
        else
          practitioner.dig('name', 'text') || format_practitioner_name(practitioner['name']) || ''
        end
      end

      def extract_condition_facility(resource)
        return '' unless resource['contained']

        location = resource['contained'].find { |item| item['resourceType'] == 'Location' }
        return '' unless location

        location['name'] || ''
      end

      def find_contained_practitioner(resource, reference)
        return nil unless reference && resource['contained']

        target_id = if reference.start_with?('#')
                      reference.delete_prefix('#')
                    else
                      reference.split('/').last
                    end

        resource['contained'].find { |res| res['id'] == target_id && res['resourceType'] == 'Practitioner' }
      end

      def format_practitioner_name(name_obj)
        return nil unless name_obj.is_a?(Hash)

        if name_obj.key?('family') && name_obj.key?('given')
          firstname = name_obj['given']&.join(' ')
          lastname = name_obj['family']
          "#{firstname} #{lastname}"
        elsif name_obj['text']
          parts = name_obj['text'].split(',')
          return name_obj['text'] if parts.length != 2

          lastname, firstname = parts.map(&:strip)
          "#{firstname} #{lastname}"
        end
      end
    end
  end
end
