# frozen_string_literal: true

require 'appeals_api/central_mail_updater'

module AppealsApi
  module NodStatus
    extend ActiveSupport::Concern

    INTERNAL_STATUSES = %w[pending submitting submitted error].freeze
    STATUSES = [*INTERNAL_STATUSES, *CentralMailUpdater::CENTRAL_MAIL_STATUSES].uniq.freeze

    IN_PROCESS_STATUSES = %w[submitted processing success].freeze
    COMPLETE_STATUSES = %w[complete].freeze

    included do
      scope :in_process_statuses, -> { where status: IN_PROCESS_STATUSES }

      validates :status, inclusion: { in: STATUSES }
    end
  end
end
