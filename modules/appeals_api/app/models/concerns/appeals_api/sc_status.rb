# frozen_string_literal: true

require 'appeals_api/central_mail_updater'

module AppealsApi
  module ScStatus
    extend ActiveSupport::Concern

    STATUSES = ['pending', 'submitting', 'submitted', *CentralMailUpdater::CENTRAL_MAIL_STATUSES, 'error'].uniq.freeze

    IN_PROCESS_STATUSES = %w[submitted processing success].freeze
    COMPLETE_STATUSES = %w[complete].freeze

    included do
      scope :in_process_statuses, -> { where status: IN_PROCESS_STATUSES }
      scope :incomplete_statuses, -> { where.not status: COMPLETE_STATUSES + %w[error] }

      validates :status, inclusion: { in: STATUSES }
    end
  end
end
