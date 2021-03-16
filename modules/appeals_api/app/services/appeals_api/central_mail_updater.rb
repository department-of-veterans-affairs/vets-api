# frozen_string_literal: true

module AppealsApi
  class CentralMailUpdater
    include SentryLogging

    MAX_UUIDS_PER_REQUEST = 100

    CENTRAL_MAIL_ERROR_STATUSES = ['Error', 'Processing Error'].freeze

    CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES = {
      'Received' => { status: 'received' },
      'Success' => { status: 'success' },

      'In Process' => { status: 'processing' },
      'Processing Success' => { status: 'processing' },

      'Error' => { status: 'error', code: 'DOC202' },
      'Processing Error' => { status: 'error', code: 'DOC202' }
    }.freeze

    CENTRAL_MAIL_STATUS = Struct.new(:id, :status, :error_message) do
      delegate :present?, to: :id

      def error?
        status.in?(CENTRAL_MAIL_ERROR_STATUSES) && error_message
      end
    end

    def call(appeals)
      return if appeals.empty?

      central_mail_response = CentralMail::Service.new.status(appeals.pluck(:id))
      unless central_mail_response.success?
        log_message_to_sentry(
          'Error getting status from Central Mail',
          :warning,
          status: central_mail_response.status,
          body: central_mail_response.body
        )
        raise Common::Exceptions::BadGateway
      end

      ActiveRecord::Base.transaction do
        update_appeals!(appeals, central_mail_response)
      end
    end

    private

    def update_appeals!(appeals, central_mail_response)
      parse_central_mail_response(central_mail_response).each do |status|
        appeal = appeals.find { |a| a.id == status.id }
        next unless appeal

        update_appeal_status!(appeal, status)
      end
    end

    def parse_central_mail_response(raw_response)
      JSON.parse(raw_response.body).flatten.map do |hash|
        CENTRAL_MAIL_STATUS.new(*hash.values_at('uuid', 'status', 'errorMessage'))
      end
    end

    def update_appeal_status!(appeal, status)
      attributes = CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES.fetch(status.status) do
        log_message_to_sentry('Unknown status value from Central Mail API', :warning, status: status.status)
        raise Common::Exceptions::BadGateway
      end

      attributes = attributes.merge(detail: "Downstream status: #{status.error_message}") if status.error?

      appeal.update! attributes
    end
  end
end
