# frozen_string_literal: true

module VaFacilities
  module ApiSerializationV1
    module_function

    def id(object)
      "#{object.facility_type_prefix}_#{object.unique_id}"
    end

    def services(object)
      result = object.services.dup
      if result.key?('health')
        health_services = result['health'].map do |s|
          [s['sl1'], s['sl2']]
        end.flatten
        result['health'] = add_wait_times(health_services, object)
      end
      result['benefits'] = result['benefits']['standard'] if result.key?('benefits')
      result
    end

    def satisfaction(object)
      result = object.feedback.dup
      result['effective_date'] = result['health'].delete('effective_date') if result.key?('health')
      result
    end

    def add_wait_times(services, object)
      result = object.access.dup

      services.each_with_object([]) do |service, with_times|
        times = result['health'][service.underscore]
        unless times.nil?
          with_times << {
            service: service,
            wait_times: {
              new: times['new'],
              established: times['established'],
              effective_date: result['health']['effective_date']
            }
          }
        end
      end
    end
  end
end
