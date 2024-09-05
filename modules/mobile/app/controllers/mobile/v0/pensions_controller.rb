# frozen_string_literal: true

require 'bid/awards/service'

module Mobile
  module V0
    class PensionsController < ApplicationController
      def index
        pension_data = pension_award_service.get_awards_pension
        extracted_data = pension_data.try(:body)&.dig('awards_pension')&.transform_keys(&:to_sym)
        raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error' unless extracted_data

        pensions = Mobile::V0::Pension.new(extracted_data)
        render json: PensionSerializer.new(pensions)
      end

      private

      def pension_award_service
        @pension_award_service ||= BID::Awards::Service.new(current_user)
      end
    end
  end
end
