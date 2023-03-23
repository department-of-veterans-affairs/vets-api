# frozen_string_literal: true

module Mobile
  class ApplicationController < SignIn::ApplicationController
    before_action :authenticate
    before_action :set_tags_and_extra_context
    skip_before_action :authenticate, only: :cors_preflight

    private

    attr_reader :current_user

    def authenticate
      return super if sis_authentication?

      StatsD.increment('iam_ssoe_oauth.auth.total')
      raise_unauthorized('Missing Authorization header') if request.headers['Authorization'].nil?
      raise_unauthorized('Authorization header Bearer token is blank') if access_token.blank?

      session_manager = IAMSSOeOAuth::SessionManager.new(access_token)
      @current_user = session_manager.find_or_create_user
      link_user_with_vets360 if @current_user.vet360_id.blank?
      StatsD.increment('iam_ssoe_oauth.auth.success')
      @current_user
    end

    def sis_authentication?
      request.headers['Authentication-Method'] == 'SIS'
    end

    def access_token
      @access_token ||= bearer_token
    end

    def raise_unauthorized(detail)
      raise Common::Exceptions::Unauthorized.new(detail:)
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
      @redis ||= Redis::Namespace.new(REDIS_CONFIG[:mobile_vets360_account_link_lock][:namespace], redis: $redis)
    end

    def lock_vets360_linking(account_uuid)
      vets360_link_redis_lock.set(account_uuid, 1)
      vets360_link_redis_lock.expire(account_uuid, REDIS_CONFIG[:mobile_vets360_account_link_lock][:each_ttl])
    end

    def vet360_linking_locked?(account_uuid)
      !vets360_link_redis_lock.get(account_uuid).nil?
    end

    def session
      return super if sis_authentication?

      Session.obscure_token(access_token)
    end

    def set_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'mobile' }
      Raven.tags_context(source: 'mobile')
    end
  end
end
