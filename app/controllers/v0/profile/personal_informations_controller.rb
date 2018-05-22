# frozen_string_literal: true

module V0
  module Profile
    class PersonalInformationsController < ApplicationController
      before_action { authorize :mvi, :queryable? }

      # Fetches the personal information for the current user.
      # Namely their gender and birth date.
      #
      # @return [Response] Sample response.body:
      #   {
      #     "data" => {
      #       "id"         => "",
      #       "type"       => "mvi_models_mvi_profiles",
      #       "attributes" => {
      #         "gender"     => "M",
      #         "birth_date" => "1949-03-04"
      #       }
      #     }
      #   }
      #
      def show
        response = Mvi.for_user(@current_user).profile

        if response&.gender.nil? || response&.birth_date.nil?
          log_message_to_sentry(
            'mvi missing data bug',
            :info,
            {
              response: response,
              params: params,
              user: @current_user.inspect,
              gender: response&.gender,
              birth_date: response&.birth_date
            },
            profile: 'pciu_profile'
          )
        end

        render json: response, serializer: PersonalInformationSerializer
      end
    end
  end
end
