# frozen_string_literal: true

require 'appeals_api/central_mail_updater'

module AppealsApi
  module AppealStatus
    extend ActiveSupport::Concern

    INTERNAL_STATUSES = %w[pending submitting submitted].freeze
    STATUSES = [*INTERNAL_STATUSES, *CentralMailUpdater::CENTRAL_MAIL_STATUSES].freeze

    RECEIVED_OR_PROCESSING = %w[received processing].freeze
    COMPLETE_STATUSES = %w[success error].freeze

    included do
      scope :received_or_processing, -> { where status: RECEIVED_OR_PROCESSING }

      validates :status, inclusion: { 'in': STATUSES }
    end
  end
end
