# frozen_string_literal: true

require 'va_profile/telephone_validation/v1/service'

module V0
  module Profile
    class TelephoneValidationController < ApplicationController
      service_tag 'profile'
      # skip_before_action :authenticate, only: [:create]

      def create
        upstream = service.validate(telephone_params.to_h)

        render json: upstream.body, status: upstream.status
      end

      private

      def telephone_params
        params.require(:telephone).permit(
          :internationalIndicator,
          :phoneType,
          :countryCode,
          :areaCode,
          :phoneNumber,
          :phoneNumberExt
        )
      end

      def service
        @service ||= VAProfile::TelephoneValidation::V1::Service.new
      end
    end
  end
end