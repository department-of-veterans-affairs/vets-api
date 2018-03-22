# frozen_string_literal: true

module V0
  module Profile
    class PersonalInformationsController < ApplicationController
      # before_action { authorize :emis, :access? }

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

        render json: response, serializer: PersonalInformationSerializer
      end
    end
  end
end
