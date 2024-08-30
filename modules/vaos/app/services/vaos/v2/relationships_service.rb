# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'json'

module VAOS
  module V2
    class RelationshipsService < VAOS::SessionService
      def get_patient_relationships(clinic_service_id, facility_id)
        with_monitoring do
          params = {
            clinicalService: clinic_service_id,
            location: facility_id
          }

          response = perform(:get, "/vpg/v1/patients/#{user.icn}/relationships", params, headers)

          response[:body][:data][:relationships].map { |relationship| OpenStruct.new(relationship) }
        end
      end
    end
  end
end
