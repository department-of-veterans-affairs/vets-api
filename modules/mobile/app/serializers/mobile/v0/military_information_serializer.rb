# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class MilitaryInformationSerializer
      include FastJsonapi::ObjectSerializer
      set_key_transform :camel_lower
      set_id :id
      attribute :service_history do |object|
        formatted_result = []
        object.service_history.each do |service_period|
          service_period.delete_field(:personnel_category_type_code)
          service_period.branch_of_service = "United States " + service_period.branch_of_service
          service_period.formatted_begin_date = service_period.begin_date.strftime("%B %d, %Y")
          service_period.formatted_end_date = service_period.end_date.strftime("%B %d, %Y")
          formatted_result.push(service_period.to_h.transform_keys{|key| key.to_s.camelize(:lower)})
        end
        formatted_result
      end
    end
  end
end
