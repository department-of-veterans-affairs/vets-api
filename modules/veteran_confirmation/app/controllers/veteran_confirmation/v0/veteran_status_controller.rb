# frozen_string_literal: true

require_dependency 'veteran_confirmation/application_controller'

module VeteranConfirmation
  module V0
    class VeteranStatusController < ApplicationController
      def index
        render json: { hit_it: 'yep' }
      rescue
        raise_error!
      end

      private

      def raise_error!
        raise Common::Exceptions::BackendServiceException.new(
          'EMIS_STATUS502',
          source: self.class.to_s
        )
      end
    end
  end
end
