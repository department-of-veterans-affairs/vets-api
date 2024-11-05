# frozen_string_literal: true

require 'lighthouse/veterans_health/client'

module Mobile
  module V0
    class AllergyIntolerancesController < ApplicationController
      def index
        response = client.list_allergy_intolerances
        allergy_intolerances = if Flipper.enabled?(:mobile_allergy_intolerance_model, @current_user)
                                 Mobile::V0::Adapters::AllergyIntolerance.new.parse(response.body['entry'])
                               else
                                 Mobile::V0::Adapters::LegacyAllergyIntolerance.new.parse(response.body['entry'])
                               end

        render json: AllergyIntoleranceSerializer.new(allergy_intolerances)
      end

      private

      def client
        @client ||= Lighthouse::VeteransHealth::Client.new(current_user.icn)
      end
    end
  end
end
