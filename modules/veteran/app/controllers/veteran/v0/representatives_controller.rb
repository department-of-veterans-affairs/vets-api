# frozen_string_literal: true

module Veteran
  module V0
    class RepresentativesController < ApplicationController
      skip_before_action :set_tags_and_extra_content, raise: false
      skip_before_action :authenticate

      def search
        rep = Veteran::Service::Representative.for_user(target)
        if rep.present?
          render json: { data: { type: 'VSO Representative', attributes: rep.as_json } }
        else
          render json: { errors: [{ detail: 'Representative not found' }] }
        end
      end

      private

      def target
        OpenStruct.new(
          first_name: params[:first_name],
          last_name: params[:last_name]
        )
      end
    end
  end
end
