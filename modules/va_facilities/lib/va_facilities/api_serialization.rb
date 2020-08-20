# frozen_string_literal: true

module VaFacilities
  module ApiSerialization
    module_function

    def id(object)
      "#{object.facility_type_prefix}_#{object.unique_id}"
    end

    def services(object)
      result = object.services.dup
      if result.key?('health')
        result['health'] = result['health'].map do |s|
          [s['sl1'], s['sl2']]
        end.flatten
      end
      result['benefits'] = result['benefits']['standard'] if result.key?('benefits')
      result
    end

    def satisfaction(object)
      result = object.feedback.dup
      result['effective_date'] = result['health'].delete('effective_date') if result.key?('health')
      result
    end

    def wait_times(object)
      result = object.access.dup
      if result.key?('health')
        result['effective_date'] = result['health'].delete('effective_date')
        result['health'] = result['health'].map do |k, v|
          {
            'service' => k.camelize,
            'new' => v['new'],
            'established' => v['established']
          }
        end
      end
      result
    end
  end
end
