# frozen_string_literal: true

require 'claims_api/claim_logger'

module ClaimsApi::OneOff
  class HeaderHashFillerJob < ClaimsApi::ServiceBase
    sidekiq_options retry: false

    LOG_TAG = 'header_hash_filler_job'

    # Testing max_to_process at 5k was 5m long, so 750 should stay under the 1m timeout limit for Sidekiq jobs
    def perform(model = 'ClaimsApi::PowerOfAttorney', ids = [], max_to_process = 750, force: false)
      return if !force && !Flipper.enabled?(:lighthouse_claims_api_run_header_hash_filler_job)
      return unless args_are_valid?(model, ids)

      # Only grab columns that are needed for processing
      cols = %i[id auth_headers_ciphertext form_data_ciphertext encrypted_kms_key status header_hash]
      relation = model.constantize.select(*cols).where(header_hash: nil)

      relation = relation.where(id: ids) unless ids.empty?

      processed_count = 0
      # batch_size adjusted for performance & memory concerns
      relation.limit(max_to_process).find_each(batch_size: 250) do |record|
        next if record.header_hash.present?

        begin
          # Save the column directly to avoid triggering callbacks
          record.set_header_hash
          record.update_column(:header_hash, record.header_hash) # rubocop:disable Rails/SkipsModelValidations
          processed_count += 1
        rescue => e
          ClaimsApi::Logger.log LOG_TAG, level: :error,
                                         detail: "Failed to fill header hash for #{model} with ID: #{record.id}",
                                         error_class: e.class.name,
                                         error_message: e.message
        end
      end
      ClaimsApi::Logger.log LOG_TAG, details: "Processed #{processed_count} records for #{model}"
    end

    private

    def args_are_valid?(model, ids)
      return false unless model.is_a?(String) && ids.is_a?(Array)
      return false unless model.constantize.method_defined?(:set_header_hash)

      true
    rescue => e # model.constantize throws if the model is invalid, but may as well catch everything
      ClaimsApi::Logger.log LOG_TAG, level: :error,
                                     detail: 'Invalid arguments provided',
                                     error_class: e.class.name,
                                     error_message: e.message
      false
    end
  end
end
