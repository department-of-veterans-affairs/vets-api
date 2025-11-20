# frozen_string_literal: true

require_relative '../models/condition'

module UnifiedHealthData
  module Adapters
    class ConditionsAdapter
      def parse(records)
        return [] if records.blank?

        filtered = records.select do |record|
          record['resource'] && record['resource']['resourceType'] == 'Condition'
        end
        parsed = filtered.map { |record| parse_single_condition(record) }
        parsed.compact
      end

      def parse_single_condition(record)
        return nil if record.nil? || record['resource'].nil?

        resource = record['resource']
        date_value = resource['onsetDateTime'] || resource['recordedDate']

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

      # Normalizes date strings for consistent sorting
      # Year-only dates (e.g., "2024") are converted to "2024-01-01T00:00:00Z"
      # Dates without time are converted to include T00:00:00Z for consistent comparison
      # Nil dates are converted to "1900-01-01T00:00:00Z" to sort at the end
      def normalize_date_for_sorting(date_value)
        return '1900-01-01T00:00:00Z' if date_value.nil?
        return "#{date_value}-01-01T00:00:00Z" if date_value.match?(/^\d{4}$/) # Year only
        return "#{date_value}T00:00:00Z" if date_value.match?(/^\d{4}-\d{2}-\d{2}$/) # Date without time
        
        date_value # Pass through dates that already have time (e.g., "2024-11-08T10:00:00Z")
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
