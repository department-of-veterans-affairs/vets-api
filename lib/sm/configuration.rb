# frozen_string_literal: true
require 'common/client/configuration'

module SM
  # Configuration class used to setup the environment used by client
  class Configuration < Common::Client::Configuration
    def base_path
      "#{@host}/mhv-sm-api/patient/v1/"
    end
  end
end
