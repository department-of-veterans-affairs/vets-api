# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V1
    class ImmunizationsController < ApplicationController
      def index
        immunizations = immunizations_adapter.parse(service.get_immunizations)
        immunizations.reverse!
        url = request.base_url + request.path
        paginated_immunizations, meta = Mobile::PaginationHelper.paginate(list: immunizations,
                                                                          validated_params: pagination_params,
                                                                          url: url)

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
        Mobile::V0::Contracts::GetPaginatedList.new.call(
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size)
        )
      end
    end
  end
end
