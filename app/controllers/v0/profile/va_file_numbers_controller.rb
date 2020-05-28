# frozen_string_literal: true

module V0
  module Profile
    class VaFileNumbersController < ApplicationController
      def show
        service = BGS::PeopleService.new
        response = service.find_person_by_ptcpnt_id(current_user)

        render(
          json: response,
          serializer: Lighthouse::People::VaFileNumberSerializer
        )
      rescue => e
        log_exception_to_sentry(e)
        raise Common::Exceptions::BackendServiceException.new(nil, detail: e.message)
      end
    end
  end
end
