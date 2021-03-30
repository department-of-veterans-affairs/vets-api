# frozen_string_literal: true

require 'common/client/configuration/rest'

module SearchTypeahead
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = 30

    def base_path
      "#{Settings.search_typeahead.url}/suggestions"
    end

    def service_name
      'SearchTypeahead'
    end
  end
end
