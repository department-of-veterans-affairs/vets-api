# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyFormSubmission < ApplicationRecord
    module Statuses
      ALL = [
        ENQUEUE_SUCCEEDED = 'enqueue_succeeded',
        ENQUEUE_FAILED = 'enqueue_failed',
        SUCCEEDED = 'succeeded',
        FAILED = 'failed'
      ].freeze
    end

    enum(
      :status,
      Statuses::ALL.index_by(&:itself),
      validate: true
    )

    belongs_to :power_of_attorney_request

    has_kms_key
    has_encrypted :service_response, key: :kms_key, **lockbox_options
    has_encrypted :error_message, key: :kms_key, **lockbox_options
  end
end
