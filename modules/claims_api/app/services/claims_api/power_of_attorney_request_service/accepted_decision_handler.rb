# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    class AcceptedDecisionHandler
      LOG_TAG = 'accepted_decision_handler'

      # rubocop:disable Metrics/ParameterLists
      def initialize(proc_id:, poa_code:, registration_number:, metadata:, veteran:, claimant: nil)
        @proc_id = proc_id
        @poa_code = poa_code
        @registration_number = registration_number
        @metadata = metadata
        @veteran = veteran
        @claimant = claimant
      end
      # rubocop:enable Metrics/ParameterLists

      def call
        ClaimsApi::Logger.log(
          LOG_TAG, message: "Starting the accepted POA workflow with proc #{@proc_id}."
        )

        gathered_data = poa_auto_establishment_gatherer
        # This returns an array to the controller [mapped_data, type]
        poa_auto_establishment_mapper(gathered_data)
      end

      private

      def poa_auto_establishment_gatherer
        ClaimsApi::PowerOfAttorneyRequestService::DataGatherer::PoaAutoEstablishmentDataGatherer.new(
          proc_id: @proc_id, registration_number: @registration_number, metadata: @metadata,
          veteran: @veteran, claimant: @claimant
        ).gather_data
      end

      def poa_auto_establishment_mapper(data)
        type = determine_type
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::PoaAutoEstablishmentDataMapper.new(
          type:,
          data:,
          veteran: @veteran
        ).map_data
      end

      def determine_type
        if poa_code_in_organization?
          '2122'
        else
          '2122a'
        end
      end

      def poa_code_in_organization?
        ::Veteran::Service::Organization.find_by(poa: @poa_code).present?
      end
    end
  end
end
