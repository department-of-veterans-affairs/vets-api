# frozen_string_literal: true

require 'appeals_api/central_mail_updater'

module AppealsApi
  module HlrStatus
    extend ActiveSupport::Concern

    V1_STATUSES = %w[pending submitting submitted processing error uploaded received success expired complete].freeze

    V2_INTERNAL_STATUSES = %w[pending submitting submitted error].freeze
    V2_STATUSES = [*V2_INTERNAL_STATUSES, *CentralMailUpdater::CENTRAL_MAIL_STATUSES].uniq.freeze

    # used primarly for reporting
    STATUSES = [*V1_STATUSES, *V2_STATUSES].uniq.freeze

    IN_PROCESS_STATUSES = %w[submitted received processing success].freeze
    COMPLETE_STATUSES = %w[complete].freeze

    included do
      scope :in_process_statuses, -> { where status: IN_PROCESS_STATUSES }
      scope :incomplete_statuses, -> { where.not status: COMPLETE_STATUSES + %w[error] }

      def versioned_statuses
        case api_version.downcase
        when 'V2'
          V2_STATUSES
        else
          V1_STATUSES
        end
      end

      validates :status, inclusion: { in: ->(appeal) { appeal.versioned_statuses } }
    end
  end
end
