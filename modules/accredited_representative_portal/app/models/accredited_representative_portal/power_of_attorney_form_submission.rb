# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyFormSubmission < ApplicationRecord
    enum :status, %w[enqueue_succeeded enqueue_failed succeeded failed].index_by(&:itself)

    belongs_to :power_of_attorney_request

    has_kms_key
    has_encrypted :service_response, key: :kms_key, **lockbox_options
    has_encrypted :error_message, key: :kms_key, **lockbox_options
  end
end
