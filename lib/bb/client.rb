# frozen_string_literal: true
require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'bb/form'
require 'bb/configuration'
require 'rx/client_session'

module BB
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient

    configuration BB::Configuration
    client_session Rx::ClientSession

    def get_extract_status
      json = perform(:get, 'bluebutton/extractstatus', nil, token_headers).body
      Common::Collection.new(ExtractStatus, json)
    end

    def get_eligible_data_classes
      json = perform(:get, 'bluebutton/geteligibledataclass', nil, token_headers).body
      EligibleDataClasses.new(json)
    end

    # These PDFs take time to generate, hence why this separate call.
    # I think we're going to have to return 204 Accepted for this, and only allow
    # downloading the report when it is available. It's not yet clear how this is possible
    # without a polling mechanism to see which reports are available.
    def post_generate(params)
      form = BB::Form.new(self, params)
      raise Common::Exceptions::ValidationErrors, form unless form.valid?
      json = perform(:post, 'bluebutton/generate', form.params, token_headers).body
    end

    def get_download_report(doctype)
      json = perform(:get, "bluebutton/bbreport/#{doctype}", nil, token_headers)
      # Not sure if this is going to be a multipart or what, will have to see the payload
      # and come up with a good way to render it.
      # Might need two controllers methods one for send_data inline, the other for saving
    end
  end
end
