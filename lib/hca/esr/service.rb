# frozen_string_literal: true
require 'common/client/base'
require 'hca/esr/configuration'
require 'hca/service'

module HCA::ESR
  class Service < HCA::Service
    configuration HCA::ESR::Configuration

    def get_form(icn: Settings.hca.ee.healthcheck_id)
      submission = client.build_request(:get_ee_summary, message:
        { requestName: 'VOARequest', key: icn })
      post_submission(submission)
    end

    private

    def client
      Savon.client(endpoint: config.base_path,
                   wsdl: HCA::ESR::Configuration::WSDL,
                   element_form_default: :unqualified,
                   wsse_auth: config.wsse)
    end
  end
end
