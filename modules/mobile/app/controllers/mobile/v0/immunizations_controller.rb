# frozen_string_literal: true

module Mobile
  module V0
    class ImmunizationsController < ApplicationController
      service_tag 'mhv-medical-records'

      def index
        render json: Mobile::V0::ImmunizationSerializer.new(immunizations_adapter.parse(service.get_immunizations))
      end

      private

      def immunizations_adapter
        Mobile::V0::Adapters::Immunizations.new
      end

      def service
        Mobile::V0::LighthouseHealth::Service.new(@current_user)
      end
    end
  end
end
