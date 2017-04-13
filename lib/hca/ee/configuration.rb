# frozen_string_literal: true
require 'hca/configuration'

module HCA::EE
  class Configuration < Common::Client::Configuration::SOAP
    include HCA::Configuration
    WSDL = Rails.root.join('config', 'health_care_application', 'wsdl', 'esr.wsdl')

    def base_path
      Settings.hca.ee.endpoint
    end

    def wsse
      [Settings.hca.ee.user, Settings.hca.ee.pass]
    end

    def service_name
      'HCA-EE'
    end
  end

  def client
    soap(namespace: 'http://va.gov/service/esr/voa/v1')
  end
end
