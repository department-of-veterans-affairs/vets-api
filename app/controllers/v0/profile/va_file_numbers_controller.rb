# frozen_string_literal: true

module V0
  module Profile
    class VaFileNumbersController < ApplicationController
      def show
        service = BGS::PeopleService.new(current_user)
        response = service.find_person_by_ptcpnt_id

        render(
          json: response,
          serializer: Lighthouse::People::VaFileNumberSerializer
        )
      end
    end
  end
end
