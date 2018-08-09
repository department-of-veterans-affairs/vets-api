module VaFacilities
  module ApiSerialization

    def id(object)
      "#{PREFIX_MAP[object.facility_type]}_#{object.unique_id}"
    end
    module_function :id

    PREFIX_MAP = {
      'va_health_facility' => 'vha',
      'va_benefits_facility' => 'vba',
      'va_cemetery' => 'nca',
      'vet_center' => 'vc'
    }.freeze

    def services(object)
      result = object.services.dup
      if result.has_key?('health')
        result['health'] = result['health'].map do |s|
          [s['sl1'], s['sl2']]
        end.flatten
      end
      if result.has_key?('benefits')
        result['benefits'] = result['benefits']['standard']
      end
      result
    end
    module_function :services

    def satisfaction(object)
      result = object.feedback.dup
      if result.has_key?('health')
        result['effective_date'] = result['health'].delete('effective_date')
      end
      result
    end
    module_function :satisfaction

    def wait_times(object)
      result = object.access.dup
      if result.has_key?('health')
        result['effective_date'] = result['health'].delete('effective_date')
        result['health'] = result['health'].map do |k,v|
          {
            'service' => k.camelize,
            'new' => v['new'],
            'established' => v['established']
          }
        end
      end
      result
    end
    module_function :wait_times

  end
end
