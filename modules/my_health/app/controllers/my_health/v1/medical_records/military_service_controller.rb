# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class MilitaryServiceController < MrController
        class MissingEdipiError < StandardError; end

        ##
        # Get a user's military service record
        #
        # @return [String] military service record in text format
        #
        def index
          raise MissingEdipiError, 'No EDIPI found for the current user' if @current_user.edipi.blank?

          resource = phrmgr_client.get_military_service(@current_user.edipi)
          render json: resource.to_json
        rescue MissingEdipiError => e
          render json: { error: e }, status: :bad_request
        end
      end
    end
  end
end
