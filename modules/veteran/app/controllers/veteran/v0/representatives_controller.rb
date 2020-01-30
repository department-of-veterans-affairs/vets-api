# frozen_string_literal: true

module Veteran
  module V0
    class RepresentativesController < ApplicationController
      skip_before_action :set_tags_and_extra_content, raise: false
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
        if params[:first_name].blank? || params[:last_name].blank?
          render json: {
            errors: [
              detail: 'First name and Last name are required to complete this request', status: 422
            ]
          }, status: 422
        end
      end
    end
  end
end
