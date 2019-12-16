# frozen_string_literal: true

require_dependency 'veteran_confirmation/application_controller'

module VeteranConfirmation
  module V0
    class VeteranStatusController < ApplicationController
      before_action :validate_body

      def index
        body = JSON.parse(string_body)

        attributes = {
          ssn: body['ssn'],
          first_name: body['first_name'],
          last_name: body['last_name'],
          birth_date: Date.iso8601(body['birth_date']).strftime('%Y%m%d')
        }

        status = StatusService.new.get_by_attributes(attributes)

        render json: { veteran_status: status }
      end

      private

      def validate_body
        raise error_klass('Body must not be empty') if string_body.blank?

        body = JSON.parse(string_body)

        body.each do |key, value|
          validate_presence(key, value)
        end

        validate_ssn_format(body['ssn'])
        vali_date(body['birth_date'])
      end

      def validate_presence(user_detail_name, user_detail_value)
        raise error_klass("Body must include #{user_detail_name}") if user_detail_value.blank?
      end

      def validate_ssn_format(ssn)
        raise error_klass('SSN must be 9 digits or have this format: 999-99-9999') unless valid_ssn?(ssn)
      end

      def valid_ssn?(ssn)
        ssn.is_a?(String) && (all_digits?(ssn) || all_digits_with_hyphens?(ssn))
      end

      def string_body
        @string_body ||= request.body.read
      end

      def all_digits?(ssn)
        /\d{9}/.match?(ssn) && ssn.size == 9
      end

      def all_digits_with_hyphens?(ssn)
        /\d{3}-\d{2}-\d{4}/.match?(ssn) && ssn.size == 11
      end

      def vali_date(date)
        Date.iso8601(date)
      rescue ArgumentError
        raise error_klass('Birth date must be a valid iso8601 format')
      end

      def error_klass(detail)
        Common::Exceptions::Unauthorized.new(detail: "Validation error: #{detail}")
      end
    end
  end
end
