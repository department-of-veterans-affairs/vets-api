# frozen_string_literal: true

require 'evss/error_middleware'

module ClaimsApi
  module V2
    class VeteranIdentifierController < ClaimsApi::V2::ApplicationController
      # TODO: REMOVE BEFORE IMPLEMENTATION
      skip_before_action :authenticate, only: %i[find]
      ICN_FOR_TEST_USER = '1012667145V762142'
      # TODO: REMOVE BEFORE IMPLEMENTATION

      def find
        raise ::Common::Exceptions::Unauthorized if request.headers['Authorization'].blank?

        validate_request

        render json: { id: ICN_FOR_TEST_USER }
      end

      private

      def validate_request
        params.require(:ssn)
        params.require(:birthdate)
        params.require(:firstName)
        params.require(:lastName)

        validate_ssn!(params[:ssn])
        validate_birthdate!(params[:birthdate])
      end

      def validate_ssn!(ssn)
        return if ssn.match?(/^\d{9}$/)

        raise ::Common::Exceptions::InvalidFieldValue.new('ssn', ssn)
      end

      def validate_birthdate!(date_str)
        date = Date.parse(date_str)
        return if date <= Time.zone.today

        raise ::Common::Exceptions::InvalidFieldValue.new('birthdate', date_str)
      rescue ArgumentError
        raise ::Common::Exceptions::InvalidFieldValue.new('birthdate', date_str)
      end
    end
  end
end
