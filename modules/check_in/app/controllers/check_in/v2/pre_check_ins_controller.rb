# frozen_string_literal: true

module CheckIn
  module V2
    class PreCheckInsController < CheckIn::ApplicationController
      def show
        head :not_implemented
      end

      def create
        head :not_implemented
      end

      private

      def pre_check_in_params
        params.require(:pre_check_in).permit(:uuid, :demographics_up_to_date, :next_of_kin_up_to_date, :check_in_type)
      end

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_pre_check_in_enabled')
      end
    end
  end
end
