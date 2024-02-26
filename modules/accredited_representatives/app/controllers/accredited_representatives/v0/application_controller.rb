# frozen_string_literal: true

module AccreditedRepresentatives
  module V0
    class ApplicationController < ApplicationController
      # Replace SERVICE_NAME with your application's service name in the Datadog Service Catalog
      # This is the dd-service property for your application here: https://github.com/department-of-veterans-affairs/vets-api/tree/master/datadog-service-catalog
      service_tag 'SERVICE_NAME'

      def index
        message = service.get_message
        render json: AccreditedRepresentativesSerializer.new(message).serialized_json
      end

      private

      def service
        @service ||= Service.new
      end
    end
  end
end
