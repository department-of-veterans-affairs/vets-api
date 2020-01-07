# frozen_string_literal: true

require_dependency 'veteran_confirmation/application_controller'

module VeteranConfirmation
  module V0
    class VeteranStatusController < ApplicationController
      before_action :validate_body

      def index
        status = StatusService.new.get_by_attributes(
          ssn: params['ssn'],
          first_name: params['first_name'],
          last_name: params['last_name'],
          birth_date: params['birth_date']
        )

        render json: { veteran_status: status }
      end

      private

      def validate_body
        params.require(%i[first_name last_name ssn birth_date])

        validate_ssn_format
        vali_date
      end

      def validate_ssn_format
        raise Common::Exceptions::InvalidFieldValue.new('ssn', 'the provided') unless valid_ssn?(params['ssn'])

        params['ssn'] = params['ssn'].gsub('-', '')
      end

      def valid_ssn?(ssn)
        ssn.is_a?(String) && (all_digits?(ssn) || all_digits_with_hyphens?(ssn))
      end

      def all_digits?(ssn)
        /^\d{9}$/.match?(ssn)
      end

      def all_digits_with_hyphens?(ssn)
        /^\d{3}-\d{2}-\d{4}$/.match?(ssn)
      end

      def vali_date
        params['birth_date'] = Date.iso8601(params['birth_date']).strftime('%Y%m%d')
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('birth_date', params['birth_date'])
      end
    end
  end
end
