# frozen_string_literal: true

module FastTrack
  class HypertensionObservationData
    attr_accessor :response

    def initialize(response)
      @response = response
    end

    def transform
      entries = response.body['entry']
      entries = entries.map { |entry| transform_entry(entry) }

      filtered_entries(entries)
    end

    private

    def filtered_entries(bp_readings)
      return [] if bp_readings.empty?

      bp_readings = bp_readings.filter do |reading|
        reading[:issued].to_date > 1.year.ago
      end

      bp_readings.sort_by do |reading|
        reading[:issued].to_datetime
      end.reverse!
    end

    def transform_entry(raw_entry)
      entry = raw_entry['resource'].slice('issued', 'component', 'performer')
      practitioner_hash = get_display_hash_from_performer('Practitioner', entry)
      organization_hash = get_display_hash_from_performer('Organization', entry)
      bp_hash = get_bp_readings_from_entry(entry)

      { issued: entry['issued'] }.merge(practitioner_hash, organization_hash, bp_hash)
    end

    def get_display_hash_from_performer(term, entry)
      result = {}
      if entry['performer'].present?
        performer_with_term = entry['performer'].detect { |item| item['reference'].include? term }
        result[term.downcase.to_sym] = performer_with_term['display'] if performer_with_term.present?
      end
      result
    end

    def get_bp_readings_from_entry(entry)
      result = {}
      # Each component should contain a BP pair, so after filtering there should only be one reading of each type:
      systolic = filter_components_by_code('8480-6', entry['component'])&.first
      diastolic = filter_components_by_code('8462-4', entry['component'])&.first

      if systolic.present? && diastolic.present?
        result[:systolic] = extract_bp_data_from_component(systolic)
        result[:diastolic] = extract_bp_data_from_component(diastolic)
      end

      result
    end

    def filter_components_by_code(code, components)
      # Filter the components to only those that have at least one code.coding element with the code:
      components&.filter { |item| item.dig('code', 'coding')&.filter { |el| el['code'] == code }&.length&.positive? }
    end

    def extract_bp_data_from_component(component)
      # component.code.coding, since we've filtered it down in filter_components_by_code,
      # should only the coding we expect, and since if there were multiples for some odd
      # reason the values in them would all be the same, we can just take the first one.
      coding = component['code']['coding'].first.slice('code', 'display')
      # The values we want are all in component.valueQuantity
      values = component['valueQuantity'].slice('unit', 'value')
      coding.merge(values)
    end
  end
end
