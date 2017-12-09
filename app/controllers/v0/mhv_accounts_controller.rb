# frozen_string_literal: true

require 'mhv_ac/account_creation_error'
require 'mhv_ac/client'
require 'sentry_logging'

module V0
  class MHVAccountsController < ApplicationController
    include SentryLogging

    STATSD_ACCOUNT_EXISTED_KEY = 'mhv.account.existed'
    STATSD_ACCOUNT_CREATION_KEY = 'mhv.account.creation'
    STATSD_ACCOUNT_UPGRADE_KEY = 'mhv.account.upgrade'

    def show
      render json: { account_state: mhv_account.account_state }
    end

    def create
      raise MHVAC::AccountCreationError if mhv_account.accessible?
      register_mhv_account unless mhv_account.previously_registered?
      upgrade_mhv_account
      head :created
    end

    private

    def mhv_account
      current_user.mhv_account
    end

    def register_mhv_account
      if mhv_account.may_register?
        client_response = mhv_ac_client.post_register(mhv_account.params_for_registration)
        if client_response[:api_completion_status] == 'Successful'
          StatsD.increment("#{STATSD_ACCOUNT_CREATION_KEY}.success")
          current_user.va_profile.mhv_ids = [client_response[:correlation_id].to_s]
          current_user.recache
          mhv_account.registered_at = Time.current
          mhv_account.register!
        end
      end
    rescue => e
      log_warning(type: :create, exception: e, extra: mhv_account.params_for_registration.slice(:icn))
      StatsD.increment("#{STATSD_ACCOUNT_CREATION_KEY}.failure")
      mhv_account.fail_register!
      raise e
    end

    def upgrade_mhv_account
      if mhv_account.may_upgrade?
        client_response = mhv_ac_client.post_upgrade(mhv_account.params_for_upgrade)
        if client_response[:status] == 'success'
          StatsD.increment("#{STATSD_ACCOUNT_UPGRADE_KEY}.success")
          mhv_account.upgraded_at = Time.current
          mhv_account.upgrade!
        end
      end
    rescue => e
      if e.is_a?(Common::Exceptions::BackendServiceException) && e.original_body['code'] == 155
        StatsD.increment(STATSD_ACCOUNT_EXISTED_KEY.to_s)
        mhv_account.upgrade! # without updating the timestamp since account was not created at vets.gov
      else
        log_warning(type: :upgrade, exception: e, extra: params_for_upgrade)
        StatsD.increment("#{STATSD_ACCOUNT_UPGRADE_KEY}.failure")
        mhv_account.fail_upgrade!
        raise e
      end
    end

    def log_warning(type:, exception:, extra: {})
      message = type == :upgrade ? 'MHV Upgrade Failed!' : 'MHV Create Failed!'
      extra_content = if exception.is_a?(Common::Exceptions::BackendServiceException)
                        extra.merge(exception_type: 'BackendServiceException', body: exception.original_body)
                      else
                        extra.merge(exception_type: exception.message)
                      end
      log_message_to_sentry(message, :warn, extra_content)
    end

    def mhv_ac_client
      @mhv_ac_client ||= MHVAC::Client.new
    end
  end
end
