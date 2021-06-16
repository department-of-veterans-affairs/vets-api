# frozen_string_literal: true

require 'evss/error_middleware'

module ClaimsApi
  module V2
    class VeteranIdentifierController < ClaimsApi::V2::ApplicationController
      # TODO: REMOVE BEFORE IMPLEMENTATION
      ICN_FOR_TEST_USER = '1012667145V762142'
      # TODO: REMOVE BEFORE IMPLEMENTATION

      def find
        raise ::Common::Exceptions::Unauthorized if request.headers['Authorization'].blank?

        validate_request
        veteran = find_veteran(params)

        render json: { id: veteran[:id] }
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

      def find_veteran(params)
        test_veteran_data = {
          id: ICN_FOR_TEST_USER,
          ssn: '796130115',
          firstName: 'Tamara',
          lastName: 'Ellis',
          birthdate: '1967-06-19'
        }

        unless params[:ssn] == test_veteran_data[:ssn]
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found')
        end

        unless params[:firstName].casecmp?(test_veteran_data[:firstName])
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found')
        end

        unless params[:lastName].casecmp?(test_veteran_data[:lastName])
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found')
        end

        unless params[:birthdate] == test_veteran_data[:birthdate]
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found')
        end

        test_veteran_data
      end
    end
  end
end
