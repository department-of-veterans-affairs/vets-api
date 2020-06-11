# frozen_string_literal: true

module V0
  module Profile
    class VaFileNumbersController < ApplicationController
      before_action { authorize :bgs, :access? }

      def show
        service = BGS::PeopleService.new(current_user)
        response = service.find_person_by_participant_id

        render(
          json: response,
          serializer: VaFileNumberSerializer
        )
      end
    end
  end
end
