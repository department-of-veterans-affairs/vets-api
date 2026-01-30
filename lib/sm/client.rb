# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'sm/client_session'
require 'sm/configuration'
require 'sm/client/attachments'
require 'sm/client/preferences'
require 'sm/client/folders'
require 'sm/client/message_drafts'
require 'sm/client/messages'
require 'sm/client/message_sending'
require 'sm/client/triage_teams'
require 'vets/collection'

module SM
  ##
  # Core class responsible for SM API interface operations
  #
  class Client < Common::Client::Base
    include Common::Client::Concerns::MHVSessionBasedClient
    include Preferences
    include Folders
    include MessageDrafts
    include Messages
    include MessageSending
    include TriageTeams
    include Attachments
    include MessageStatus

    configuration SM::Configuration
    client_session SM::ClientSession

    MHV_MAXIMUM_PER_PAGE = 250
    STATSD_KEY_PREFIX = 'mhv.sm.api.client'

    def current_user
      @current_user ||= User.find(session.user_uuid)
    end

    def mobile_client?
      instance_of?(::Mobile::V0::Messaging::Client)
    end

    def my_health_client?
      instance_of?(::SM::Client)
    end

    def client_type_name
      return 'mobile' if mobile_client?
      return 'my_health' if my_health_client?

      'unknown'
    end

    def oh_pilot_user?
      current_user.present? && Flipper.enabled?(:mhv_secure_messaging_cerner_pilot, current_user)
    end

    def get_cached_or_fetch_data(use_cache, cache_key, model)
      data = nil
      data = model.get_cached(cache_key) if use_cache

      if data
        Rails.logger.info("secure messaging #{model} cache fetch", cache_key)
        track_metric('cache.hit')
        Vets::Collection.new(data, model)
      else
        Rails.logger.info("secure messaging #{model} service fetch", cache_key)
        track_metric('cache.miss')
        yield
      end
    end

    def get_session_tagged
      Sentry.set_tags(error: 'mhv_sm_session')
      path = append_requires_oh_messages_query('session')
      env = perform(:get, path, nil, auth_headers)
      Sentry.get_current_scope.tags.delete(:error)
      env
    end

    private

    def auth_headers
      config.base_request_headers.merge(
        'appToken' => config.app_token,
        'mhvCorrelationId' => session.user_id.to_s,
        'x-api-key' => config.x_api_key
      )
    end

    def token_headers
      config.base_request_headers.merge(
        'Token' => session.token,
        'x-api-key' => config.x_api_key
      )
    end

    def reply_draft?(id)
      get_message_history(id).records.present?
    end

    def append_requires_oh_messages_query(path, param_name = 'requiresOHMessages')
      if oh_pilot_user?
        separator = path.include?('?') ? '&' : '?'
        path += "#{separator}#{param_name}=1"
      end
      path
    end

    ##
    # @!group StatsD
    ##
    # Report stats of secure messaging events
    #
    #

    ##
    #
    # @param key [String] the metric key (will be prefixed with STATSD_KEY_PREFIX)
    # @param additional_tags [Hash] optional tags as key-value pairs (e.g., ehr_source: 'vista')
    #
    def track_metric(key, is_oh: false, **additional_tags)
      tags = ["platform:#{mobile_client? ? 'mobile' : 'web'}"]
      tags << "ehr_source:#{is_oh ? 'oracle_health' : 'vista'}"
      additional_tags.each { |k, v| tags << "#{k}:#{v}" }
      StatsD.increment("#{STATSD_KEY_PREFIX}.#{key}", tags:)
    end

    ##
    # Track a StatsD metric with status (success/failure) based on block execution
    #
    # @param key [String] the metric key (will be prefixed with STATSD_KEY_PREFIX)
    # @param is_oh [Boolean] whether this is an Oracle Health request
    # @param additional_tags [Hash] optional tags as key-value pairs
    # @yield the operation to track
    # @return the result of the block
    #
    def track_with_status(key, is_oh: false, **additional_tags)
      result = yield
      track_metric(key, is_oh:, status: 'success', **additional_tags)
      result
    rescue => e
      track_metric(key, is_oh:, status: 'failure', **additional_tags)
      raise e
    end

    # @!endgroup
  end
end
