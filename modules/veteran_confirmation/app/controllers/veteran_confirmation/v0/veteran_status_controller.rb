# frozen_string_literal: true

require_dependency 'veteran_confirmation/application_controller'

module VeteranConfirmation
  module V0
    class VeteranStatusController < ApplicationController
      def index
        body = JSON.parse(request.body.read)

        attributes = {
          ssn: body['ssn'],
          first_name: body['first_name'],
          last_name: body['last_name'],
          birth_date: Date.iso8601(body['birth_date']).strftime('%Y%m%d')
        }

        status = StatusService.new.get_by_attributes(attributes)

        render json: { veteran_status: status }
      end
    end
  end
end
