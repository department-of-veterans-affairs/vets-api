# frozen_string_literal: true

module AppealsApi
  class CentralMailUpdater
    include SentryLogging

    MAX_UUIDS_PER_REQUEST = 100

    CENTRAL_MAIL_ERROR_STATUSES = ['Error'].freeze

    CENTRAL_MAIL_STATUS_ATTRIBUTES = {
      'Received' => { status: 'submitted' }, # received upstream of our API
      'In Process' => { status: 'processing' }, # indicates vba intake
      'Success' => { status: 'success' }, # received by the centralized mail portal
      'VBMS Complete' => { status: 'complete' }, # document package received by vbms
      'Error' => { status: 'error', code: 'DOC202' }
    }.freeze

    CENTRAL_MAIL_STATUSES = CENTRAL_MAIL_STATUS_ATTRIBUTES.to_a.map { |_, x| x.fetch(:status) }.freeze

    CENTRAL_MAIL_STATUS = Struct.new(:id, :_status, :error_message, :packets) do
      # ex. packets => [{"veteranId"=>"123456789", "status"=>"Complete", "completedReason"=>"DownloadConfirmed",
      #                  "transactionDate"=>"2022-05-06"}]
      delegate :present?, to: :id

      def status
        if _status == 'Complete'
          packet_results_status
        else
          _status
        end
      end

      def error?
        status.in?(CENTRAL_MAIL_ERROR_STATUSES) && error_message
      end

      def packet_results_status
        if Array(packets).any? { |p| p['completedReason'] == 'UnidentifiableMail' }
          'Error'
        else
          'VBMS Complete'
        end
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

      update_appeals!(appeals, central_mail_response)
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
        CENTRAL_MAIL_STATUS.new(*hash.values_at('uuid', 'status', 'errorMessage', 'packets'))
      end
    end

    def update_appeal_status!(appeal, central_mail_status)
      attributes = CENTRAL_MAIL_STATUS_ATTRIBUTES.fetch(central_mail_status.status) do
        log_message_to_sentry(
          'Unknown status value from Central Mail API',
          :warning,
          status: central_mail_status.status
        )
        raise Common::Exceptions::BadGateway
      end

      if central_mail_status.error?
        attributes = attributes.merge(detail: "Downstream status: #{central_mail_status.error_message}")
      end

      begin
        appeal.update_status!(**attributes)
      rescue => e
        log_exception e, appeal, central_mail_status.status
      end
    end

    def log_exception(e, appeal, status)
      details = {
        class: self.class.to_s,
        appeal_type: appeal.class.to_s,
        appeal_id: appeal.id,
        appeal_status: appeal.status,
        attempted_status: status
      }

      log_exception_to_sentry e, details

      slack_details = {
        exception: e.class.to_s,
        exception_message: e.message,
        detail: 'Error when trying to update appeal status'
      }.merge(details)

      AppealsApi::Slack::Messager.new(slack_details).notify!
    end
  end
end
