# frozen_string_literal: true

module V0
  module Profile
    class ValidVaFileNumbersController < ApplicationController
      before_action { authorize :bgs, :access? }

      def show
        service = BGS::PeopleService.new(current_user)
        response = service.find_person_by_participant_id

        render(
          json: valid_va_file_number_data(response),
          serializer: ValidVaFileNumberSerializer
        )
      end

      private

      def valid_va_file_number_data(service_response)
        return { file_nbr: true } if service_response[:file_nbr].present?

        { file_nbr: false }
      end
    end
  end
end
