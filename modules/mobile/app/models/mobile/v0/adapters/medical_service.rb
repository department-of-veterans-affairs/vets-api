# frozen_string_literal: true

require 'common/models/base'
require 'date'

module Mobile
  module V0
    module Adapters
      class MedicalService
        # 411 = Podiatry
        SERVICE_TYPE_IDS = %w[amputation audiology covid optometry outpatientMentalHealth moveProgram foodAndNutrition
                              clinicalPharmacyPrimaryCare 411 primaryCare homeSleepTesting socialWork].freeze

        def parse(service_eligibilities)
          SERVICE_TYPE_IDS.collect do |service|
            request_facilities = []
            direct_facilities = []

            service_eligibilities.each do |facility|
              facility_id = facility.facility_id
              facility_service = facility.services.find { |h| h[:id] == service }
              next if facility_service.nil?

              request_facilities << facility_id if facility_service.dig(:request, :enabled)
              direct_facilities << facility_id if facility_service.dig(:direct, :enabled)
            end

            Mobile::V0::MedicalService.new(
              name: service,
              request_eligible_facilities: request_facilities,
              direct_eligible_facilities: direct_facilities
            )
          end
        end
      end
    end
  end
end
