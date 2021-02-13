# frozen_string_literal: true

module AppealsApi
  class CentralMailUpdater
    include SentryLogging

    STATUSES = %w[pending submitting submitted processing error uploaded received success expired].freeze

    CENTRAL_MAIL_ERROR_STATUSES = ['Error', 'Processing Error'].freeze
    RECEIVED_OR_PROCESSING = %w[received processing].freeze
    COMPLETE_STATUSES = %w[success error].freeze

    CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES = {
      'Received' => { status: 'received' },
      'Success' => { status: 'success' },

      'In Process' => { status: 'processing' },
      'Processing Success' => { status: 'processing' },

      'Error' => { status: 'error', code: 'DOC202' },
      'Processing Error' => { status: 'error', code: 'DOC202' }
    }.freeze

    def call(appeals)
      return if appeals.empty?

      response = CentralMail::Service.new.status(appeals.pluck(:id))
      unless response.success?
        # should the appeal know about sentry?
        appeals[0].log_message_to_sentry(
          'Error getting status from Central Mail',
          :warning,
          status: response.status,
          body: response.body
        )
        raise Common::Exceptions::BadGateway
      end

      central_mail_status_objects = parse_central_mail_response(response).select { |struct| struct.id.present? }

      ActiveRecord::Base.transaction do
        central_mail_status_objects.each do |obj|
          appeal = appeals.find { |h| h.id == obj.id }
          update_appeal_status(appeal: appeal, status: obj.status, error_message: obj.error_message)
        end
      end
    end

    private

    def parse_central_mail_response(response)
      JSON.parse(response.body).flatten.map do |hash|
        Struct.new(:id, :status, :error_message).new(*hash.values_at('uuid', 'status', 'errorMessage'))
      end
    end

    def update_appeal_status(appeal:, status:, error_message:)
      begin
        attributes = CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES.fetch(status)
      rescue KeyError
        log_message_to_sentry('Unknown status value from Central Mail API', :warning, status: status)
        raise Common::Exceptions::BadGateway
      end

      if status.in?(CENTRAL_MAIL_ERROR_STATUSES) && error_message
        attributes = attributes.merge(detail: "Downstream status: #{error_message}")
      end

      appeal.update! attributes
    end
  end
end
