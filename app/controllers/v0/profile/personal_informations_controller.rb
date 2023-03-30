# frozen_string_literal: true

require 'va_profile/demographics/service'

module V0
  module Profile
    class PersonalInformationsController < ApplicationController
      before_action { authorize :mpi, :queryable? }

      # Fetches the personal information for the current user.
      # Namely their gender, birth date, preferred name, and gender identity.
      def show
        response = service.get_demographics

        handle_errors!(response)

        render(
          json: response,
          status: response.status,
          serializer: PersonalInformationSerializer
        )
      end

      private

      def service
        VAProfile::Demographics::Service.new @current_user
      end

      def handle_errors!(response)
        raise_error! if response.gender.blank? && response.birth_date.blank?

        log_errors_for(response)
      end

      def raise_error!
        raise Common::Exceptions::BackendServiceException.new(
          'MVI_BD502',
          source: self.class.to_s
        )
      end

      def log_errors_for(response)
        if response.gender.nil? || response.birth_date.nil?
          log_message_to_sentry(
            'mpi missing data bug',
            :info,
            {
              response:,
              params:,
              gender: response.gender,
              birth_date: response.birth_date
            },
            profile: 'pciu_profile'
          )
        end
      end
    end
  end
end
