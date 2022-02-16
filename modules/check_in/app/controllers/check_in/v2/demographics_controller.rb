# frozen_string_literal: true

module CheckIn
  module V2
    class DemographicsController < CheckIn::ApplicationController
      before_action :before_logger, only: %i[update], if: :additional_logging?
      after_action :after_logger, only: %i[update], if: :additional_logging?

      def update
        head :not_implemented
      end

      def permitted_params
        params.require(:demographics).permit(:demographic_confirmations)
      end
    end
  end
end
