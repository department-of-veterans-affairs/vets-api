# frozen_string_literal: true

module AppealsApi
  module CentralMailStatus
    extend ActiveSupport::Concern

    include SentryLogging

    STATUSES = %w[pending submitting submitted processing error uploaded received success expired].freeze

    CENTRAL_MAIL_ERROR_STATUSES = ['Error', 'Processing Error'].freeze
    RECEIVED_OR_PROCESSING = %w[received processing].freeze
    COMPLETE_STATUSES = %w[success error].freeze

    CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES = lambda do
      hash = Hash.new { |_, _| raise ArgumentError, 'Unknown Central Mail status' }
      hash['Received'] = { status: 'received' }
      hash['In Process'] = { status: 'processing' }
      hash['Processing Success'] = hash['In Process']
      hash['Success'] = { status: 'success' }
      hash['Error'] = { status: 'error', code: 'DOC202' }
      hash['Processing Error'] = hash['Error']
      hash
    end.call.freeze

    included do
      scope :received_or_processing, -> { where status: RECEIVED_OR_PROCESSING }

      validates :status, inclusion: { 'in': STATUSES }
    end
  end
end
