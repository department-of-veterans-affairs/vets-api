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

        UnifiedHealthData::Condition.new(
          id: resource['id'],
          date: resource['onsetDateTime'] || resource['recordedDate'],
          name: resource.dig('code', 'coding', 0, 'display') || resource.dig('code', 'text') || '',
          provider: extract_condition_provider(resource),
          facility: extract_condition_facility(resource),
          comments: extract_condition_comments(resource)
        )
      end

      private

      def extract_condition_comments(resource)
        return [] unless resource['note']

        if resource['note'].is_a?(Array)
          resource['note'].map { |note| note['text'] }.compact
        else
          [resource['note']['text']].compact
        end
      end

      def extract_condition_provider(resource)
        return resource.dig('asserter', 'display') || '' unless resource['contained']

        practitioner = resource['contained'].find { |item| item['resourceType'] == 'Practitioner' }
        return '' unless practitioner

        practitioner.dig('name', 0, 'text') || ''
      end

      def extract_condition_facility(resource)
        return resource.dig('encounter', 'display') || '' unless resource['contained']

        location = resource['contained'].find { |item| item['resourceType'] == 'Location' }
        return '' unless location

        location['name'] || ''
      end
    end
  end
end
