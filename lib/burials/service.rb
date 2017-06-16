# frozen_string_literal: true
require 'common/client/base'

module Burials
  class Service < Common::Client::Base
    configuration Burials::Configuration

    def get_cemeteries
      soap = savon_client.build_request(:get_cemeteries, message: {})
      json = perform(:post, '', soap.body).body

      Common::Collection.new(::Cemetery, data: json[:cemeteries])
    end

    private

    def savon_client
      @savon ||= Savon.client(wsdl: Settings.burials.preneeds_wsdl)
    end
  end
end
