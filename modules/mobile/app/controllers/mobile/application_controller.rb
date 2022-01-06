# frozen_string_literal: true

module Mobile
  class ApplicationController < ActionController::API
    include ExceptionHandling
    include Headers
    include Pundit
    include SentryLogging
    include SentryControllerLogging

    before_action :authenticate
    before_action :set_tags_and_extra_context
    skip_before_action :authenticate, only: :cors_preflight

    ACCESS_TOKEN_REGEX = /^Bearer /.freeze

    def cors_preflight
      head(:ok)
    end

    private

    attr_reader :current_user

    def authenticate
      raise_unauthorized('Missing Authorization header') if request.headers['Authorization'].nil?
      raise_unauthorized('Authorization header Bearer token is blank') if access_token.blank?

      session_manager = IAMSSOeOAuth::SessionManager.new(access_token)
      @current_user = session_manager.find_or_create_user
      map_logingov_to_idme
      link_user_with_vets360 if @current_user.vet360_id.blank?
      @current_user
    end

    def access_token
      @access_token ||= request.headers['Authorization']&.gsub(ACCESS_TOKEN_REGEX, '')
    end

    def raise_unauthorized(detail)
      raise Common::Exceptions::Unauthorized.new(detail: detail)
    end

    def link_user_with_vets360
      uuid = @current_user.uuid

      unless vet360_linking_locked?(uuid)
        lock_vets360_linking(uuid)
        jid = Mobile::V0::Vet360LinkingJob.perform_async(uuid)
        Rails.logger.info('Mobile Vet360 account link job id', { job_id: jid })
      end
    end

    def vets360_link_redis_lock
      @redis ||= Redis::Namespace.new(REDIS_CONFIG[:mobile_vets360_account_link_lock][:namespace], redis: Redis.current)
    end

    def lock_vets360_linking(account_uuid)
      vets360_link_redis_lock.set(account_uuid, 1)
      vets360_link_redis_lock.expire(account_uuid, REDIS_CONFIG[:mobile_vets360_account_link_lock][:each_ttl])
    end

    def vet360_linking_locked?(account_uuid)
      !vets360_link_redis_lock.get(account_uuid).nil?
    end

    def append_info_to_payload(payload)
      super
      payload[:session] = Session.obscure_token(access_token) if access_token.present?
      payload[:user_uuid] = current_user.uuid if current_user.present?
    end

    def set_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'mobile' }
      Raven.tags_context(source: 'mobile')
    end

    # this method is a temporary solution so old app version will still treat LOGINGOV accounts as multifactor
    def map_logingov_to_idme
      if @current_user.identity.sign_in[:service_name].include? 'LOGINGOV'
        @current_user.identity.sign_in[:service_name] = 'oauth_IDME'
      end
    end
  end
end
