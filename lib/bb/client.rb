# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'common/client/concerns/streaming_client'
require 'bb/generate_report_request_form'
require 'bb/configuration'
require 'rx/client_session'

module BB
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient
    include Common::Client::StreamingClient
    include SentryLogging

    configuration BB::Configuration
    client_session Rx::ClientSession

    # PHR refresh, this should be called once per user, will take up to 15 minutes
    # to process, but its the only way to refresh a user's data
    def get_extract_status
      json = perform(:get, 'bluebutton/extractstatus', nil, token_headers).body
      log_refresh_errors(json[:data]) if refresh_final?(json[:data])
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

    # Get a health record report. Because of potentially large payload size
    # the content must be streamed.
    # doctype - one of: "txt" or "pdf"
    # header_callback - should be a callable that will accept an enumerator of
    #   response headers as key/value pairs
    # yielder - a target to which a stream of response body chunks can be
    #   yielded (see for example Enumerator.new)
    def get_download_report(doctype, header_callback, yielder)
      # TODO: For testing purposes, use one of the following static URIs:
      # uri = URI("#{Settings.mhv.rx.host}/vetsgov/1mb.file")
      # uri = URI("#{Settings.mhv.rx.host}/vetsgov/90mb.file")
      uri = URI.join(config.base_path, "bluebutton/bbreport/#{doctype}")
      streaming_get(uri, token_headers, header_callback, yielder)
    end

    private

    def refresh_final?(attrs)
      attrs.all? { |e| e[:status].present? }
    end

    def log_refresh_errors(attrs)
      failed = attrs.select { |e| e[:status] == 'ERROR' }.map { |e| e[:extract_type] }
      if failed.present?
        log_message_to_sentry('Final health record refresh contained one or more error statuses', :warn,
                              refresh_failures: failed.sort)
      end
    end
  end
end
