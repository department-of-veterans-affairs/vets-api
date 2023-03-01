# frozen_string_literal: true

module Identity
  class UserAcceptableVerifiedCredentialTotalsJob
    include Sidekiq::Worker

    STATSD_KEY_PREFIX = 'worker.user_avc_totals'

    SCOPES = [WITH_AVC = :with_avc,
              WITH_IVC = :with_ivc,
              WITHOUT_AVC = :without_avc,
              WITHOUT_IVC = :without_ivc,
              WITHOUT_AVC_IVC = :without_avc_ivc].freeze

    PROVIDERS = [ALL = :all,
                 IDME = :idme,
                 LOGINGOV = :logingov,
                 DSLOGON = :dslogon,
                 MHV = :mhv].freeze

    def perform
      set_statsd_gauges
    end

    private

    ##
    # Set StatsD gauge for all user_avc_totals.[PROVIDERS].[SCOPES].total combinations
    def set_statsd_gauges
      base_query = UserAcceptableVerifiedCredential.joins(user_account: :user_verifications).distinct

      SCOPES.each do |scope|
        mhv_dslogon_combined_total = 0
        scoped_query = base_query.merge(UserAcceptableVerifiedCredential.public_send(scope))

        PROVIDERS.each do |provider|
          count = if provider == ALL
                    scoped_query.count
                  else
                    scoped_query.merge(UserVerification.public_send(provider)).count
                  end

          StatsD.gauge("#{STATSD_KEY_PREFIX}.#{provider}.#{scope}.total", count)

          # MHV and DSLOGON combined total
          mhv_dslogon_combined_total += count if [MHV, DSLOGON].include?(provider)
        end

        # MHV_DSLOGON Combined gauge
        StatsD.gauge("#{STATSD_KEY_PREFIX}.#{MHV}_#{DSLOGON}.#{scope}.total", mhv_dslogon_combined_total)
      end
    end
  end
end
