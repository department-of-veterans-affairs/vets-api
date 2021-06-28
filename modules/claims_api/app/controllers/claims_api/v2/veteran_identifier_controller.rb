# frozen_string_literal: true

require 'evss/error_middleware'

module ClaimsApi
  module V2
    class VeteranIdentifierController < ClaimsApi::V2::ApplicationController
      def find
        validate_request
        veteran = find_veteran(params)

        raise ::Common::Exceptions::ResourceNotFound unless veteran_icn_found?(veteran)

        user_is_the_veteran   = current_user_is_the_veteran?(veteran: veteran, user: @current_user)
        user_is_a_veteran_rep = current_user_is_a_veteran_representative?(@current_user)
        raise ::Common::Exceptions::Unauthorized unless user_is_the_veteran || user_is_a_veteran_rep

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

      def current_user_is_a_veteran_representative?(user)
        representative = ::Veteran::Service::Representative.find_by(
          first_name: user.first_name,
          last_name: user.last_name
        )

        representative.present?
      end

      def current_user_is_the_veteran?(user:, veteran:)
        return false unless user.first_name.casecmp?(veteran.first_name)
        return false unless user.last_name.casecmp?(veteran.last_name)
        return false unless user.ssn == veteran.ssn
        return false unless birth_dates_match?(user_birth_date: user.birth_date, veteran_birth_date: veteran.birth_date)

        true
      end

      def birth_dates_match?(user_birth_date:, veteran_birth_date:)
        validate_birthdate!(veteran_birth_date)
        validate_birthdate!(user_birth_date)
        Date.parse(veteran_birth_date) == Date.parse(user_birth_date)
      rescue ArgumentError
        false
      end
    end
  end
end
