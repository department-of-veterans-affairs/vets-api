# frozen_string_literal: true
require 'common/client/configuration'

module SM
  class Configuration < Common::Client::Configuration
    def base_path
      "#{@host}/mhv-sm-api/patient/v1/"
    end
  end
end
