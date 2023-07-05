# frozen_string_literal: true

module Chip
  class Configuration < Common::Client::Configuration::REST
    def base_path; end

    def service_name
      'Chip'
    end
  end
end
