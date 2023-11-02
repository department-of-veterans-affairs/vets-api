# frozen_string_literal: true

require 'lighthouse/veterans_health/client'

module Mobile
  module V0
    class AllergyIntolerancesController < ApplicationController
      def index
        response = client.list_allergy_intolerances
        allergy_intolerances = Mobile::V0::Adapters::AllergyIntolerance.new.parse(response.body['entry'])

        render json: AllergyIntoleranceSerializer.new(allergy_intolerances)
      end

      private

      def client
        @client ||= Lighthouse::VeteransHealth::Client.new(current_user.icn)
      end
    end
  end
end
