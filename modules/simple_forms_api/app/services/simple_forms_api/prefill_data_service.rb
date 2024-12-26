# frozen_string_literal: true

module SimpleFormsApi
  class PrefillDataService
    attr_reader :prefill_data, :form_data, :form_id

    def initialize(prefill_data:, form_data:, form_id:)
      @prefill_data = JSON.parse(prefill_data)
      @form_data = form_data
      @form_id = form_id
    end

    def check_for_changes
      changed_fields = []
      changed_fields << 'first_name' if prefill_data.dig('full_name', 'first') != form_data.dig('full_name', 'first')
      changed_fields << 'last_name' if prefill_data.dig('full_name', 'last') != form_data.dig('full_name', 'last')
      changed_fields << 'postal_code' if prefill_data.dig('address', 'postal_code') != form_data['postal_code']
      changed_fields << 'ssn' if prefill_data.dig('veteran', 'ssn') != form_data.dig('id_number', 'ssn')
      changed_fields << 'email' if prefill_data['email'] != form_data['email']

      changed_fields.each do |field|
        Rails.logger.info('Simple forms api - Form Upload Flow changed data', { field:, form_id: })
      end
    end
  end
end
