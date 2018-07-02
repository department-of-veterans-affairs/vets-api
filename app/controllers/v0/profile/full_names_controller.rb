# frozen_string_literal: true

module V0
  module Profile
    class FullNamesController < ApplicationController
      include Vet360::Writeable

      # Fetches the full name details for the current user.
      # Namely their first/middle/last name, and suffix.
      #
      # @return [Response] Sample response.body:
      #   {
      #     "data" => {
      #       "id"         => "",
      #       "type"       => "hashes",
      #       "attributes" => {
      #         "first"  => "Jack",
      #         "middle" => "Robert",
      #         "last"   => "Smith",
      #         "suffix" => "Jr."
      #       }
      #     }
      #   }
      #
      def show
        log_profile_data_to_sentry('') if @current_user&.full_name_normalized.blank?

        render(
          json: @current_user.full_name_normalized,
          serializer: FullNameSerializer
        )
      end
    end
  end
end
