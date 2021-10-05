# frozen_string_literal: true

module Mobile
  module V0
    class MaintenanceWindowSerializer
      include FastJsonapi::ObjectSerializer

      attributes :service,
                 :start_time,
                 :end_time
    end
  end
end
