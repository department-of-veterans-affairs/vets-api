# frozen_string_literal: true

module AppealsApi
  module HlrStatus
    extend ActiveSupport::Concern

    STATUSES = %w[pending submitting submitted processing error uploaded received success expired].freeze

    RECEIVED_OR_PROCESSING = %w[received processing].freeze
    COMPLETE_STATUSES = %w[success error].freeze

    included do
      scope :received_or_processing, -> { where status: RECEIVED_OR_PROCESSING }

      validates :status, inclusion: { in: STATUSES }
    end
  end
end
