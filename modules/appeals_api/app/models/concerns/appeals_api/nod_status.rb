# frozen_string_literal: true

require 'appeals_api/central_mail_updater'

module AppealsApi
  module NodStatus
    extend ActiveSupport::Concern

    INTERNAL_STATUSES = %w[pending submitting submitted].freeze
    STATUSES = [*INTERNAL_STATUSES, *CentralMailUpdater::CENTRAL_MAIL_STATUSES].uniq.freeze

    RECEIVED_OR_PROCESSING = %w[submitted processing].freeze
    COMPLETE_STATUSES = %w[success caseflow error].freeze

    included do
      scope :received_or_processing, -> { where status: RECEIVED_OR_PROCESSING }

      validates :status, inclusion: { in: STATUSES }
    end
  end
end
