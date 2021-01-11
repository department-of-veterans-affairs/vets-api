# frozen_string_literal: true

module AppealsApi
  module CentralMailStatus
    extend ActiveSupport::Concern

    include SentryLogging

    # rubocop:disable Metrics/BlockLength
    class_methods do
      def refresh_statuses_using_central_mail!(appeals)
        return if appeals.empty?

        response = CentralMail::Service.new.status(appeals.pluck(:id))

        unless response.success?
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
            appeals.find { |h| h.id == obj.id }
                   .update_status_using_central_mail_status!(obj.status, obj.error_message)
          end
        end
      end

      private

      def parse_central_mail_response(response)
        JSON.parse(response.body).flatten.map do |hash|
          Struct.new(:id, :status, :error_message).new(*hash.values_at('uuid', 'status', 'errorMessage'))
        end
      end
    end

    included do
      scope :received_or_processing, -> { where status: RECEIVED_OR_PROCESSING }

      STATUSES = %w[pending submitting submitted processing error uploaded received success expired].freeze

      validates :status, inclusion: { 'in': STATUSES }

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

      def update_status_using_central_mail_status!(status, error_message = nil)
        begin
          attributes = CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES[status] || {}
        rescue ArgumentError
          log_message_to_sentry('Unknown status value from Central Mail API', :warning, status: status)
          raise Common::Exceptions::BadGateway
        end

        if status.in?(CENTRAL_MAIL_ERROR_STATUSES) && error_message
          attributes = attributes.merge(detail: "Downstream status: #{error_message}")
        end

        update! attributes
      end
    end

    # the following three validations are called in tests to ensure that the statuses above are written correctly
    def status_attributes_valid?
      # check to ensure the subject file has the correct statuses coded
      CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES.values.all? do |attributes|
        [:status, 'status'].all? do |status|
          !attributes.key?(status) || attributes[status].in?(STATUSES)
        end
      end
    end

    def error_statuses_valid?
      # check to ensure the subject file has the correct statuses coded
      CENTRAL_MAIL_ERROR_STATUSES.all? do |error_status|
        CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES.keys.include?(error_status)
      end
    end

    def statuses_valid?
      # check to ensure the subject file has the correct statuses coded
      [*RECEIVED_OR_PROCESSING, *COMPLETE_STATUSES].all? { |status| STATUSES.include?(status) }
    end
    # rubocop:enable Metrics/BlockLength
  end
end
