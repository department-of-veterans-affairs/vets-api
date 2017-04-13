# frozen_string_literal: true
require 'common/client/base'
require 'hca/ee/configuration'
require 'hca/service'

module HCA::EE
  class Service < HCA::Service
    configuration HCA::EE::Configuration

    def get_form(icn: Settings.hca.ee.healthcheck_id)
      submission = client.build_request(:get_ee_summary, message:
        { requestName: 'VOARequest', key: icn }) # ,
      post_submission(submission)
    end

    private

    def client
      Savon.client(wsdl: HCA::EE::Configuration::WSDL, element_form_default: :unqualified, wsse_auth: config.wsse)
    end
  end
end
