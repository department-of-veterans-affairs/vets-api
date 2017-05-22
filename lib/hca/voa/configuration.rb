# frozen_string_literal: true
require 'hca/configuration'

module HCA::VOA
  class Configuration < Common::Client::Configuration::SOAP
    include HCA::Configuration

    WSDL = Rails.root.join('config', 'health_care_application', 'wsdl', 'voa.wsdl')

    def base_path
      Settings.hca.voa&.endpoint || Settings.hca.endpoint
    end

    def service_name
      'HCA-VOA'
    end
  end
end
