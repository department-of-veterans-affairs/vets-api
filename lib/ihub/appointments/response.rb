# frozen_string_literal: true

require 'common/client/concerns/service_status'
require 'vets/model'
require 'ihub/models/appointment'

module IHub
  module Appointments
    class Response
      include Vets::Model
      include Common::Client::Concerns::ServiceStatus

      attribute :status, Integer
      attribute :appointments, IHub::Models::Appointment, array: true, default: []

      def initialize(attributes = nil)
        super(attributes) if attributes
        self.status = attributes[:status]
      end

      def self.from(response)
        all_appointments = response.body&.fetch('data', [])

        new(
          status: response.status,
          appointments: IHub::Models::Appointment.build_all(all_appointments)
        )
      end

      def ok?
        status == 200
      end

      def cache?
        ok?
      end

      def metadata
        { status: response_status }
      end

      def response_status
        case status
        when 200
          RESPONSE_STATUS[:ok]
        when 403
          RESPONSE_STATUS[:not_authorized]
        when 404
          RESPONSE_STATUS[:not_found]
        else
          RESPONSE_STATUS[:server_error]
        end
      end
    end
  end
end
