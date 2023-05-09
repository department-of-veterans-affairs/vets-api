# frozen_string_literal: true

module Mobile
  module V1
    class ImmunizationsController < ApplicationController
      def index
        paginated_immunizations, meta = Mobile::PaginationHelper.paginate(list: immunizations,
                                                                          validated_params: pagination_params)

        render json: Mobile::V0::ImmunizationSerializer.new(paginated_immunizations, meta)
      end

      private

      def immunizations_adapter
        Mobile::V0::Adapters::Immunizations.new
      end

      def service
        Mobile::V0::LighthouseHealth::Service.new(@current_user)
      end

      def pagination_params
        @pagination_params ||= Mobile::V0::Contracts::Immunizations.new.call(
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          use_cache: params[:useCache] || true
        )
      end

      def immunizations
        immunizations = Mobile::V0::Immunization.get_cached(@current_user) if pagination_params[:use_cache]

        if immunizations
          Rails.logger.info('mobile immunizations cache fetch', user_uuid: @current_user.uuid)
        else
          immunizations = immunizations_adapter.parse(service.get_immunizations)
          Mobile::V0::Immunization.set_cached(@current_user, immunizations)
          Rails.logger.info('mobile immunizations service fetch', user_uuid: @current_user.uuid)
        end

        immunizations
      end
    end
  end
end
