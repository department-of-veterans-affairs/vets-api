# frozen_string_literal: true

module V0
  module Profile
    class ValidVAFileNumbersController < ApplicationController
      service_tag 'profile'
      before_action { authorize :bgs, :access? }

      def show
        response = BGS::People::Request.new.find_person_by_participant_id(user: current_user)

        valid_file_number = valid_va_file_number_data(response)
        render json: ValidVAFileNumberSerializer.new(valid_file_number)
      end

      private

      def valid_va_file_number_data(service_response)
        return { file_nbr: true } if service_response.file_number.present?

        { file_nbr: false }
      end
    end
  end
end
