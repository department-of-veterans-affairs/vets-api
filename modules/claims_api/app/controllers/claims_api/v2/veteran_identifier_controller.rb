# frozen_string_literal: true

require 'evss/error_middleware'

module ClaimsApi
  module V2
    class VeteranIdentifierController < ClaimsApi::V2::ApplicationController
      def find
        raise ::Common::Exceptions::Unauthorized if request.headers['Authorization'].blank?

        validate_request
        veteran = find_veteran(params)

        unless veteran_icn_found?(veteran)
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found')
        end

        render json: { id: veteran.mpi.icn }
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
        ClaimsApi::Veteran.new(
          uuid: params[:ssn],
          ssn: params[:ssn],
          first_name: params[:firstName],
          last_name: params[:lastName],
          va_profile: ClaimsApi::Veteran.build_profile(params[:birthdate]),
          loa: @current_user.loa
        )
      end

      def veteran_icn_found?(veteran)
        veteran&.mpi&.icn.present?
      end
    end
  end
end
