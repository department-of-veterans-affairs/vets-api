# frozen_string_literal: true

module V0
  module Profile
    class FullNamesController < ApplicationController
      service_tag 'profile'

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
        render json: FullNameSerializer.new(@current_user.full_name_normalized)
      end
    end
  end
end
