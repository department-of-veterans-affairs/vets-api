# frozen_string_literal: true

module SOB
  module V0
    class Ch33StatusesController < ApplicationController
      service_tag 'statement-of-benefits'

      skip_before_action :authenticate

      def show
        response = service.get_ch33_status
        render json: SOB::Ch33StatusSerializer.new(response)
      end

      private

      def service
        SOB::DGIB::Service.new('204')
      end
    end
  end
end
