# frozen_string_literal: true

require 'hca/configuration'

module VA1010Forms
  module ServiceUtils
    def soap
      # Savon *seems* like it should be setting these things correctly
      # from what the docs say. Our WSDL file is weird, maybe?
      Savon.client(
        wsdl: HCA::Configuration::WSDL,
        env_namespace: :soap,
        element_form_default: :qualified,
        namespaces: {
          'xmlns:tns': 'http://va.gov/service/esr/voa/v1'
        },
        namespace: 'http://va.gov/schema/esr/voa/v1'
      )
    end
  end
end
