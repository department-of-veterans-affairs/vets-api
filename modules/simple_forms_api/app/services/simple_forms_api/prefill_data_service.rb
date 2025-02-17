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
      changed_fields = form_upload_field_paths.map do |key, value|
        key if prefill_data.dig(*value[:prefill_path]) != form_data.dig(*value[:form_data_path])
      end.compact

      changed_fields.each do |field|
        Rails.logger.info('Simple forms api - Form Upload Flow changed data', { field:, form_id: })
      end
    end

    private

    def form_upload_field_paths
      {
        first_name: { prefill_path: %w[full_name first], form_data_path: %w[full_name first] },
        last_name: { prefill_path: %w[full_name last], form_data_path: %w[full_name last] },
        postal_code: { prefill_path: %w[address postal_code], form_data_path: %w[postal_code] },
        ssn: { prefill_path: %w[veteran ssn], form_data_path: %w[id_number ssn] },
        email: { prefill_path: %w[email], form_data_path: %w[email] }
      }
    end
  end
end
