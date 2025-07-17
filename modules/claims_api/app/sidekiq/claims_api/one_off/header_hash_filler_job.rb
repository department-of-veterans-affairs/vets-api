# frozen_string_literal: true

require 'claims_api/claim_logger'

module ClaimsApi::OneOff
  class HeaderHashFillerJob < ClaimsApi::ServiceBase
    sidekiq_options retry: false

    LOG_TAG = 'header_hash_filler_job'

    def perform(model = 'ClaimsApi::PowerOfAttorney', ids = [], batch_size: 5_000)
      return unless args_are_valid?(model, ids)

      relation = model.constantize.where(header_hash: nil)
      relation = relation.where(id: ids) unless ids.empty?

      count = 0
      relation.limit(batch_size).find_each do |record|
        next if record.header_hash.present?

        begin
          # Since
          record.save! touch: false
          count += 1
        rescue => e
          ClaimsApi::Logger.log LOG_TAG, level: :error,
                                         detail: "Failed to fill header hash for #{model} with ID: #{record.id}",
                                         error_class: e.class.name,
                                         error_message: e.message
        end
      end
      ClaimsApi::Logger.log LOG_TAG, details: "#{model} completed with #{count} record(s)"
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
