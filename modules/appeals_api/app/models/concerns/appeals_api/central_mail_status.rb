# frozen_string_literal: true

require 'central_mail/service'

module AppealsApi
  module CentralMailStatus
    extend ActiveSupport::Concern

    STATUSES = %w[pending submitting submitted processing error uploaded received success expired].freeze

    CENTRAL_MAIL_STATUS_TO_APPEALS_ATTRIBUTES = lambda do
      hash = Hash.new { |_, _| raise ArgumentError, 'Unknown Central Mail status' }
      hash['Received'] = { status: 'received' }
      hash['In Process'] = { status: 'processing' }
      hash['Processing Success'] = hash['In Process']
      hash['Success'] = { status: 'success' }
      hash['Error'] = { status: 'error', code: 'DOC202' }
      hash['Processing Error'] = hash['Error']
      hash
    end.call.freeze
    # ensure that statuses in map are valid statuses
    raise unless CENTRAL_MAIL_STATUS_TO_APPEALS_ATTRIBUTES.values.all? do |attributes|
      [:status, 'status'].all? do |status|
        !attributes.key?(status) || attributes[status].in?(STATUSES)
      end
    end

    CENTRAL_MAIL_ERROR_STATUSES = ['Error', 'Processing Error'].freeze
    raise unless CENTRAL_MAIL_ERROR_STATUSES - CENTRAL_MAIL_STATUS_TO_APPEALS_ATTRIBUTES.keys == []

    RECEIVED_OR_PROCESSING = %w[received processing].freeze
    raise unless RECEIVED_OR_PROCESSING - STATUSES == []

    COMPLETE_STATUSES = %w[success error].freeze
    raise unless COMPLETE_STATUSES - STATUSES == []

    included do
      def central_mail_status
        CentralMail::Service.new.status(id)
      end

      def update_status_using_central_mail_status!(status, error_message = nil)
        begin
          attributes = CENTRAL_MAIL_STATUS_TO_APPEALS_ATTRIBUTES[status] || {}
        rescue ArgumentError
          self.class.log_unknown_central_mail_status(status)
          raise Common::Exceptions::BadGateway, detail: 'Unknown processing status'
        end

        if status.in?(CENTRAL_MAIL_ERROR_STATUSES) && error_message
          attributes = attributes.merge(detail: "Downstream status: #{error_message}")
        end

        update! attributes
      end

      scope :received_or_processing, -> { where status: RECEIVED_OR_PROCESSING }
      scope :completed, -> { where status: COMPLETE_STATUSES }
    end

    # rubocop:disable Metrics/BlockLength
    class_methods do
      def refresh_statuses_using_central_mail!(appeals)
        return if appeals.empty?

        response = CentralMail::Service.new.status(appeals.pluck(:id))
        unless response.success?
          log_bad_central_mail_response(response)
          raise Common::Exceptions::BadGateway
        end

        central_mail_status_objects = parse_central_mail_response(response).select { |s| s.id.present? }
        ActiveRecord::Base.transaction do
          central_mail_status_objects.each do |obj|
            appeals.find { |h| h.id == obj.id }
                   .update_status_using_central_mail_status!(obj.status, obj.error_message)
          end
        end
      end

      def log_unknown_central_mail_status(status)
        log_message_to_sentry('Unknown status value from Central Mail API', :warning, status: status)
      end

      private

      def parse_central_mail_response(response)
        JSON.parse(response.body).flatten.map do |hash|
          Struct.new(:id, :status, :error_message).new(*hash.values_at('uuid', 'status', 'errorMessage'))
        end
      end

      def log_bad_central_mail_response(resp)
        log_message_to_sentry('Error getting status from Central Mail', :warning, status: resp.status, body: resp.body)
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
