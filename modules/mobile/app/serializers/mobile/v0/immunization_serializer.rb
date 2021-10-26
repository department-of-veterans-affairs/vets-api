# frozen_string_literal: true

module Mobile
  module V0
    class ImmunizationSerializer
      include FastJsonapi::ObjectSerializer

      attributes :cvx_code,
                 :date,
                 :dose_number,
                 :dose_series,
                 :group_name,
                 :manufacturer,
                 :note,
                 :short_description
    end
  end
end
