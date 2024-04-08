# frozen_string_literal: true

require 'bgs/awards_service'

module Mobile
  module V0
    class AwardsController < ApplicationController
      def index
        award_data = regular_award_service.get_awards
        raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error' unless award_data

        award_data[:id] = current_user.uuid
        awards = Mobile::V0::Award.new(award_data)
        render json: AwardSerializer.new(awards)
      end

      private

      def regular_award_service
        @regular_award_service ||= BGS::AwardsService.new(current_user)
      end
    end
  end
end
