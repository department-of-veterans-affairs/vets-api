# frozen_string_literal: true
require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'bb/generate_report_request_form'
require 'bb/configuration'
require 'rx/client_session'

module BB
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient

    configuration BB::Configuration
    client_session Rx::ClientSession

    # PHR refresh, this should be called once per user, will take up to 15 minutes
    # to process, but its the only way to refresh a user's data
    def get_extract_status
      json = perform(:get, 'bluebutton/extractstatus', nil, token_headers).body
      Common::Collection.new(ExtractStatus, json)
    end

    # These are to be used to build the checkboxes for the form used to make a
    # generate report request
    def get_eligible_data_classes
      json = perform(:get, 'bluebutton/geteligibledataclass', nil, token_headers).body
      EligibleDataClasses.new(json)
    end

    # These PDFs take time to generate, hence why this separate call just to generate.
    # It should be quick enough that download report can be called more or less right after
    def post_generate(params)
      form = BB::GenerateReportRequestForm.new(self, params)
      raise Common::Exceptions::ValidationErrors, form unless form.valid?
      perform(:post, 'bluebutton/generate', form.params, token_headers).body
    end

    # doctype must be one of: txt or pdf
    def get_download_report(doctype)
      perform(:get, "bluebutton/bbreport/#{doctype}", nil, token_headers)
    end
  end
end
