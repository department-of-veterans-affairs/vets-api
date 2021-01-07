# frozen_string_literal: true

module AppealsApi
  module CentralMailStatus
    extend ActiveSupport::Concern

    include SentryLogging

    included do
      scope :received_or_processing, -> { where status: RECEIVED_OR_PROCESSING }

      STATUSES = %w[pending submitting submitted processing error uploaded received success expired].freeze

      validates :status, inclusion: { 'in': STATUSES }

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

      raise "One or more CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES values is invalid" unless status_attributes_valid?

      CENTRAL_MAIL_ERROR_STATUSES = ['Error', 'Processing Error'].freeze
      raise "One or more CENTRAL_MAIL_ERROR_STATUSES is invalid" unless error_statuses_valid?

      RECEIVED_OR_PROCESSING = %w[received processing].freeze
      raise "One or more RECEIVED_OR_PROCESSING stats invalid" unless statuses_valid?(RECEIVED_OR_PROCESSING)

      COMPLETE_STATUSES = %w[success error].freeze
      raise "One or more COMPLETE_STATUSES is invalid" unless statuses_valid?(COMPLETE_STATUSES)

      def update_status_using_central_mail_status!(status, error_message = nil)
        begin
          attributes = CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES[status] || {}
        rescue ArgumentError
          # TODO: test logging
          log_message_to_sentry('Unknown status value from Central Mail API', :warning, status: status)
          raise Common::Exceptions::BadGateway, detail: 'Unknown processing status'
        end
        if status.in?(CENTRAL_MAIL_ERROR_STATUSES) && error_message
          attributes = attributes.merge(detail: "Downstream status: #{error_message}")
        end

        update! attributes
      end
    end

    class_methods do
      def refresh_statuses_using_central_mail!(appeals)
        return if appeals.empty?

        response = CentralMail::Service.new.status(appeals.pluck(:id))

        unless response.success?
          # TODO: need better solution & Need to test
          appeals[0].log_message_to_sentry('Error getting status from Central Mail', :warning, status: response.status, body: response.body)
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

      def date_from_string(string)
        string.match(/\d{4}-\d{2}-\d{2}/) && Date.parse(string)
      rescue ArgumentError
        nil
      end

      private

      def parse_central_mail_response(response)
        JSON.parse(response.body).flatten.map do |hash|
          Struct.new(:id, :status, :error_message).new(*hash.values_at('uuid', 'status', 'errorMessage'))
        end
      end

      def status_attributes_valid?
        CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES.values.all? do |attributes|
          [:status, 'status'].all? do |status|
            !attributes.key?(status) || attributes[status].in?(STATUSES)
          end
        end
      end

      def error_statuses_valid?
        CENTRAL_MAIL_ERROR_STATUSES.all? do |error_status|
          CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES.keys.include?(error_status)
        end
      end

      def statuses_valid?(statuses)
        statuses.all? { |status| STATUSES.include?(status) }
      end
    end
  end
end
