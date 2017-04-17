# frozen_string_literal: true
require 'common/client/base'
require 'emis/configuration'
require 'emis/messages/edipi_message'
require 'emis/responses/get_veteran_status_response'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require 'emis/errors/errors'

module EMIS
  class Service < Common::Client::Base
    protected

    def create_edipi_message(edipi)
      # raise Common::Exceptions::ValidationErrors, user unless user.valid?(:loa3_user)
      EMIS::Messages::EdipiMessage.new(edipi).to_xml
    end
  end
end
