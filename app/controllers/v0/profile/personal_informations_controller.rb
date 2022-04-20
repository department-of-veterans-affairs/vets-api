# frozen_string_literal: true

module V0
  module Profile
    class PersonalInformationsController < ApplicationController
      before_action { authorize :mpi, :queryable? }

      # Fetches the personal information for the current user.
      # Namely their gender and birth date.
      def show
        response = OpenStruct.new({
                                    'id': @current_user.account_uuid,
                                    'type': 'mvi_models_mvi_profiles',
                                    'gender': @current_user.gender_mpi,
                                    'birth_date': @current_user.birth_date_mpi
                                  })
        handle_errors!(response)

        render json: response, serializer: PersonalInformationSerializer
      end

      private

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
              response: response,
              params: params,
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
