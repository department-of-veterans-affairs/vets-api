# frozen_string_literal: true

module V0
  module Profile
    class ValidVAFileNumbersController < ApplicationController
      before_action { authorize :bgs, :access? }

      def show
        response = BGS::People::Request.new.find_person_by_participant_id(user: current_user)

        render(
          json: valid_va_file_number_data(response),
          serializer: ValidVAFileNumberSerializer
        )
      end

      private

      def valid_va_file_number_data(service_response)
        return { file_nbr: true } if service_response.file_number.present?

        { file_nbr: false }
      end
    end
  end
end
