# frozen_string_literal: true

require 'bgs/awards_service'
require 'bid/awards/service'

module Mobile
  module V0
    class AwardsController < ApplicationController
      def index
        award_data = regular_award_service.get_awards
        award_data.merge!(pension_award_service.get_awards_pension.body['awards_pension']&.transform_keys(&:to_sym))
        award_data[:id] = current_user.uuid
        awards = Mobile::V0::Award.new(award_data)
        render json: AwardSerializer.new(awards)
      end

      private

      def regular_award_service
        @regular_award_service ||= BGS::AwardsService.new(current_user)
      end

      def pension_award_service
        @pension_award_service ||= BID::Awards::Service.new(current_user)
      end
    end
  end
end
