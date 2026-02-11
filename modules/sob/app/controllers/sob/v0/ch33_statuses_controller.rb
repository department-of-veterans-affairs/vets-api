# frozen_string_literal: true

module SOB
  module V0
    class Ch33StatusesController < ApplicationController
      service_tag 'statement-of-benefits'

      def show
        response = service.get_ch33_status
        render json: SOB::Ch33StatusSerializer.new(response)
      end

      private

      def service
        SOB::DGI::Service.new(ssn: @current_user&.ssn)
      end
    end
  end
end
