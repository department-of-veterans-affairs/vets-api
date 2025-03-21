# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'common/client/concerns/streaming_client'
require 'bb/generate_report_request_form'
require 'bb/configuration'
require 'rx/client_session'

module BB
  ##
  # Core class responsible for BB API interface operations
  #
  class Client < Common::Client::Base
    include Common::Client::Concerns::MHVSessionBasedClient
    include Common::Client::Concerns::StreamingClient
    include SentryLogging

    configuration BB::Configuration
    client_session Rx::ClientSession

    CACHE_TTL = 3600 * 3 # cache for 3 hours

    LEGACY_BASE_PATH = "#{Settings.mhv.rx.host}/mhv-api/patient/v1".freeze
    APIGW_BASE_PATH = "#{Settings.mhv.api_gateway.hosts.bluebutton}/v1/bluebutton".freeze
    APIGW_AUTH_BASE_PATH = "#{Settings.mhv.api_gateway.hosts.bluebutton}/v1/usermgmt/auth".freeze

    ##
    # PHR (Personal Health Record) refresh
    #
    # @note this should be called once per user, will take up to 15 minutes
    #   to process, but its the only way to refresh a user's data
    # @return [Common::Collection]
    #
    def get_extract_status
      _, prefix = base_path_and_prefix
      json = perform(:get, "#{prefix}/extractstatus", nil, token_headers).body
      log_refresh_errors(json[:data]) if refresh_final?(json[:data])
      Common::Collection.new(ExtractStatus, **json)
    end

    ##
    # Build the checkboxes for the form used to make a generate report request
    #
    # @return [Common::Collection]
    #
    def get_eligible_data_classes
      _, prefix = base_path_and_prefix
      Common::Collection.fetch(::EligibleDataClass, cache_key: cache_key('geteligibledataclass'), ttl: CACHE_TTL) do
        perform(:get, "#{prefix}/geteligibledataclass", nil, token_headers).body
      end
    end

    ##
    # Trigger a BB report generation
    #
    # @note These PDFs take time to generate, hence why this separate call just to generate.
    #   It should be quick enough that download report can be called more or less right after
    # @param params [Hash] an object containing a date range and array of data classes
    # @raise [Common::Exceptions::ValidationErrors] if there are validation errors
    # @return [Hash] an object containing the body of the response
    #
    def post_generate(params)
      form = BB::GenerateReportRequestForm.new(self, params)
      raise Common::Exceptions::ValidationErrors, form unless form.valid?

      _, prefix = base_path_and_prefix
      perform(:post, "#{prefix}/generate", form.params, token_headers).body
    end

    ##
    # Get a health record report. Because of potentially large payload size
    # the content must be streamed.
    #
    # @param doctype [String] one of: "txt" or "pdf"
    # @param header_callback [Proc] should be a callable that will accept an enumerator of
    #   response headers as key/value pairs
    # @param yielder [Enumerable::Yielder] a target to which a stream of response body chunks can be
    #   yielded (see for example Enumerator.new)
    #
    def get_download_report(doctype, header_callback, yielder)
      # TODO: For testing purposes, use one of the following static URIs:
      # uri = URI("#{Settings.mhv.rx.host}/vetsgov/1mb.file")
      # uri = URI("#{Settings.mhv.rx.host}/vetsgov/90mb.file")
      base, prefix = base_path_and_prefix
      uri = URI.join(config.base_path, "#{base}/#{prefix}/bbreport/#{doctype}")
      streaming_get(uri, token_headers, header_callback, yielder)
    end

    ##
    # Opt user in to VHIE sharing.
    #
    def post_opt_in
      base_path, = base_path_and_prefix
      prefix = base_path == APIGW_BASE_PATH ? '' : 'bluebutton/external/'
      perform(:post, "#{prefix}optinout/optin", nil, token_headers).body
    rescue ServiceException => e
      # Ignore the error that the user is already opted in to VHIE sharing.
      raise unless e.message.include? 'already.opted.in'
    end

    ##
    # Opt user out of VHIE sharing.
    #
    def post_opt_out
      base_path, = base_path_and_prefix
      prefix = base_path == APIGW_BASE_PATH ? '' : 'bluebutton/external/'
      perform(:post, "#{prefix}optinout/optout", nil, token_headers).body
    rescue ServiceException => e
      # Ignore the error that the user is already opted out of VHIE sharing.
      raise unless e.message.include? 'Opt-out consent policy is already set'
    end

    ##
    # Get current status of user's VHIE sharing.
    #
    # @return [Hash] an object containing the body of the response
    #
    def get_status
      base_path, = base_path_and_prefix
      prefix = base_path == APIGW_BASE_PATH ? '' : 'bluebutton/external/'
      perform(:get, "#{prefix}optinout/status", nil, token_headers).body
    end

    private

    def base_path_and_prefix
      if Flipper.enabled?(:mhv_medical_records_migrate_to_api_gateway)
        BB::Configuration.custom_base_path = APIGW_BASE_PATH
        [APIGW_BASE_PATH, 'ess']
      else
        BB::Configuration.custom_base_path = LEGACY_BASE_PATH
        [LEGACY_BASE_PATH, 'bluebutton']
      end
    end

    def get_session_tagged
      Sentry.set_tags(error: 'mhv_session')
      BB::Configuration.custom_base_path = if Flipper.enabled?(:mhv_medical_records_migrate_to_api_gateway)
                                             APIGW_AUTH_BASE_PATH
                                           else
                                             LEGACY_BASE_PATH
                                           end
      env = perform(:get, 'session', nil, auth_headers)

      Sentry.get_current_scope.tags.delete(:error)
      env
    end

    def cache_key(action)
      return nil unless config.caching_enabled?
      return nil if session.user_id.blank?

      "#{session.user_id}:#{action}"
    end

    def refresh_final?(attrs)
      attrs.all? { |e| e[:status].present? }
    end

    def log_refresh_errors(attrs)
      failed = attrs.select { |e| e[:status] == 'ERROR' }.pluck(:extract_type)
      if failed.present?
        log_message_to_sentry('Final health record refresh contained one or more error statuses', :warn,
                              refresh_failures: failed.sort)
      end
    end
  end
end
