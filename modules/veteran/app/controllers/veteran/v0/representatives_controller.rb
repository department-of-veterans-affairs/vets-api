# frozen_string_literal: true

module Veteran
  module V0
    class RepresentativesController < ApplicationController
      skip_before_action :authenticate
      before_action :check_required_fields

      # Currently only used by the SAML proxy and not documented for external use
      def find_rep
        rep = Veteran::Service::Representative.for_user(first_name: params[:first_name], last_name: params[:last_name])
        if rep.present?
          render json: rep,
                 serializer: Veteran::Service::RepresentativeSerializer
        else
          render json: { errors: [{ detail: 'Representative not found' }] },
                 status: :not_found
        end
      end

      private

      def check_required_fields
        errors = []
        errors << error_hash('first_name') if params[:first_name].blank?
        errors << error_hash('last_name') if params[:last_name].blank?
        render json: { errors: }, status: :unprocessable_entity if errors.any?
      end

      def error_hash(parameter)
        {
          detail: "#{parameter.humanize} is required to complete this request",
          title: 'Missing Parameter',
          source: { parameter: },
          status: 422
        }
      end
    end
  end
end
