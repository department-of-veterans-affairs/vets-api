# frozen_string_literal: true

module Mobile
  module V0
    class MaintenanceWindowsController < ApplicationController
      skip_before_action :authenticate

      # deers? vacols? corpDB?
      # lighthouse upstream service documentation:
      # https://github.com/department-of-veterans-affairs/leeroy-jenkles/wiki/API-Backend-Systems#api-to-va-backend-mapping
      SERVICE_GRAPH = Mobile::V0::ServiceGraph.new(
        %i[bgs lighthouse],
        %i[mpi lighthouse],
        %i[bgs caseflow],
        %i[bgs payment_history],
        %i[arcgis facility_locator],
        %i[caseflow appeals],
        %i[vapro_military_info military_service_history],
        %i[vbms evss],
        %i[vbms lighthouse],
        %i[vbms efolder],
        %i[lighthouse claims],
        %i[lighthouse_direct_deposit direct_deposit_benefits],
        %i[evss disability_rating],
        %i[evss letters_and_documents],
        %i[lighthouse immunizations],
        %i[mhv_platform mhv_sm],
        %i[mhv_platform mhv_meds],
        %i[mhv_sm secure_messaging],
        %i[mhv_meds rx_refill],
        %i[vaos appointments],
        %i[vapro_personal_info user_demographics],
        %i[vapro_contact_info user_contact_update],
        %i[eoas preneed_burial],
        %i[travel_pay travel_pay_features]
      )

      def index
        render json: Mobile::V0::MaintenanceWindowSerializer.new(maintenance_windows)
      end

      private

      def maintenance_windows
        upstream_maintenance_windows = ::MaintenanceWindow.end_after(Time.zone.now)
        SERVICE_GRAPH.affected_services(upstream_maintenance_windows).values
      end
    end
  end
end
