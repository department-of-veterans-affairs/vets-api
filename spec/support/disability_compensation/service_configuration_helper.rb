# frozen_string_literal: true

module DisabilityCompensation
  ##
  # TODO: Explain this.
  # TODO: Extract to a top-level spec helper so others can use this?
  #
  module ServiceConfigurationHelper
    def reset_service_configuration(service, configuration)
      Singleton.__init__(configuration)
      service.remove_instance_variable(:@configuration)
      service.configuration(configuration)
    end
  end
end
