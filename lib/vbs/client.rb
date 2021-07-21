# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'

module VBS
  class Client < Common::Client::Base
    configuration VBS::Configuration

    def exec(vbs_request, skip_request_validation: false)
      vbs_request.validate! unless skip_request_validation
      perform(vbs_request.http_method, vbs_request.path, vbs_request.data)
    end
  end
end
