# frozen_string_literal: true

require 'appeals_api/central_mail_updater'

module AppealsApi
  module ScStatus
    extend ActiveSupport::Concern

    INTERNAL_STATUSES = %w[pending submitting submitted].freeze
    STATUSES = [*INTERNAL_STATUSES, *CentralMailUpdater::CENTRAL_MAIL_STATUSES].uniq.freeze

    IN_PROCESS_STATUSES = %w[submitted processing].freeze
    COMPLETE_STATUSES = %w[success caseflow error].freeze

    included do
      scope :in_process_statuses, -> { where status: IN_PROCESS_STATUSES }
      scope :incomplete_statuses, -> { where.not status: COMPLETE_STATUSES }

      validates :status, inclusion: { in: STATUSES }
    end
  end
end
