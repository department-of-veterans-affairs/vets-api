# frozen_string_literal: true

module AppealsApi
  class CentralMailUpdater
    include SentryLogging

    MAX_UUIDS_PER_REQUEST = 100

    CENTRAL_MAIL_ERROR_STATUSES = ['Error', 'Processing Error'].freeze

    NOD_CENTRAL_STATUS_ATTRIBUTES = {
      # we are consolidating submitted/received into one status for clarity
      'Received' => { status: 'submitted' },
      'Success' => { status: 'success' },

      'In Process' => { status: 'processing' },
      'Processing Success' => { status: 'processing' },

      'Error' => { status: 'error', code: 'DOC202' },
      'Processing Error' => { status: 'error', code: 'DOC202' },

      'VBMS Complete' => { status: 'caseflow' }
    }.freeze

    CENTRAL_MAIL_STATUSES = NOD_CENTRAL_STATUS_ATTRIBUTES.to_a.map { |_, x| x.fetch(:status) }.uniq.freeze

    HLR_CENTRAL_STATUS_ATTRIBUTES = {
      'Received' => { status: 'received' },

      'Success' => { status: 'success' },
      'VBMS Complete' => { status: 'success' },

      'In Process' => { status: 'processing' },
      'Processing Success' => { status: 'processing' },

      'Error' => { status: 'error', code: 'DOC202' },
      'Processing Error' => { status: 'error', code: 'DOC202' }
    }.freeze

    V2_HLR_CENTRAL_STATUS_ATTRIBUTES = NOD_CENTRAL_STATUS_ATTRIBUTES

    CENTRAL_MAIL_STATUS = Struct.new(:id, :_status, :error_message, :packets) do
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
          'Success'
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
        CENTRAL_MAIL_STATUS.new(*hash.values_at('uuid', 'status', 'errorMessage', 'packets'))
      end
    end

    def update_appeal_status!(appeal, central_mail_status)
      attributes = central_mail_status_lookup(appeal).fetch(central_mail_status.status) do
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

      appeal.update_status! attributes
    end

    def central_mail_status_lookup(appeal)
      case appeal
      when AppealsApi::NoticeOfDisagreement then NOD_CENTRAL_STATUS_ATTRIBUTES
      when AppealsApi::SupplementalClaim then V2_HLR_CENTRAL_STATUS_ATTRIBUTES
      when AppealsApi::HigherLevelReview
        case appeal.api_version
        when 'V2' then V2_HLR_CENTRAL_STATUS_ATTRIBUTES
        else HLR_CENTRAL_STATUS_ATTRIBUTES
        end
      end
    end
  end
end
