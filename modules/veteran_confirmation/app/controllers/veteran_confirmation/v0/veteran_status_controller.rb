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
        parameters_exist?(%w[first_name last_name ssn birth_date])

        validate_ssn_format(params['ssn'])
        vali_date(params['birth_date'])
      end

      def parameters_exist?(to_check)
        to_check.each do |field|
          if params[field].blank?
            raise Common::Exceptions::ParameterMissing.new(field,
                                                           detail: "Must supply #{field} to query Veteran status")
          end
        end
      end

      def validate_ssn_format(ssn)
        raise Common::Exceptions::InvalidFieldValue.new('ssn', 'the provided') unless valid_ssn?(ssn)

        params['ssn'] = ssn.gsub('-', '')
      end

      def valid_ssn?(ssn)
        ssn.is_a?(String) && (all_digits?(ssn) || all_digits_with_hyphens?(ssn))
      end

      def all_digits?(ssn)
        /\d{9}/.match?(ssn) && ssn.size == 9
      end

      def all_digits_with_hyphens?(ssn)
        /\d{3}-\d{2}-\d{4}/.match?(ssn) && ssn.size == 11
      end

      def vali_date(date)
        params['birth_date'] = Date.iso8601(date).strftime('%Y%m%d')
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('birth_date', params['birth_date'])
      end
    end
  end
end
