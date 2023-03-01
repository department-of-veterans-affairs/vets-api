# frozen_string_literal: true

module Login
  class UserAcceptableVerifiedCredentialUpdaterLogger
    STATSD_KEY_PREFIX = 'api.user_avc_updater'
    LOG_MESSAGE = '[UserAcceptableVerifiedCredentialUpdater] - User AVC Updated'
    FROM_TYPES = [MHV_TYPE = 'mhv', DSLOGON_TYPE = 'dslogon', IDME_TYPE = 'idme', LOGINGOV_TYPE = 'logingov'].freeze
    ADDED_TYPES = [AVC_TYPE = 'avc', IVC_TYPE = 'ivc'].freeze

    def initialize(user_acceptable_verified_credential:)
      @user_avc = user_acceptable_verified_credential
    end

    def perform
      return if user_avc.nil?

      increment_statsd
      log_info
    end

    private

    attr_reader :user_avc

    def increment_statsd
      statsd_keys.each do |key|
        StatsD.increment(key, 1)
      end
    end

    def log_info
      Rails.logger.info(LOG_MESSAGE, log_payload)
    end

    def statsd_keys
      @statsd_keys ||= build_statsd_keys
    end

    def log_payload
      @log_payload ||= build_log_payload
    end

    def added_type
      @added_type ||= if avc_added?
                        AVC_TYPE
                      elsif ivc_added?
                        IVC_TYPE
                      end
    end

    def added_from_type
      @added_from_type ||= if from_mhv?
                             MHV_TYPE
                           elsif from_dslogon?
                             DSLOGON_TYPE
                           elsif from_logingov?
                             LOGINGOV_TYPE
                           elsif from_idme?
                             IDME_TYPE
                           end
    end

    def build_statsd_keys
      keys = []
      return keys unless added_type.present? && added_from_type.present?

      keys << "#{STATSD_KEY_PREFIX}.#{added_from_type}.#{added_type}.added"

      if added_from_type == MHV_TYPE || added_from_type == DSLOGON_TYPE
        keys << "#{STATSD_KEY_PREFIX}.#{MHV_TYPE}_#{DSLOGON_TYPE}.#{added_type}.added"
      end

      keys
    end

    def build_log_payload
      payload = {}

      payload[:added_type] = added_type
      payload[:added_from] = added_from_type if added_from_type.present?
      payload[:user_account_id] = user_account.id
      payload[:mhv_uuid] = mhv_credential.mhv_uuid if added_from_type == MHV_TYPE
      payload[:dslogon_uuid] = dslogon_credential.dslogon_uuid if added_from_type == DSLOGON_TYPE
      payload[:backing_idme_uuid] = backing_idme_uuid if backing_idme_uuid.present?
      payload[:idme_uuid] = idme_credential&.idme_uuid
      payload[:logingov_uuid] = logingov_credential&.logingov_uuid

      payload
    end

    def user_account
      @user_account ||= user_avc.user_account
    end

    def idme_credential
      @idme_credential ||= user_verifications.idme.first
    end

    def logingov_credential
      @logingov_credential ||= user_verifications.logingov.first
    end

    def mhv_credential
      @mhv_credential ||= user_verifications.mhv.first
    end

    def dslogon_credential
      @dslogon_credential ||= user_verifications.dslogon.first
    end

    def backing_idme_uuid
      @backing_idme_uuid ||= if from_mhv?
                               mhv_credential.backing_idme_uuid
                             elsif from_dslogon?
                               dslogon_credential.backing_idme_uuid
                             end
    end

    def user_verifications
      @user_verifications ||= user_account.user_verifications
    end

    def avc_added?
      user_avc.saved_change_to_acceptable_verified_credential_at?
    end

    def ivc_added?
      user_avc.saved_change_to_idme_verified_credential_at?
    end

    # When the newly added verified_credential_at is the only one that exists and
    # the user has a mhv credential it is from mhv e.g. user_avc_updater.mhv.{added_type}.added
    def from_mhv?
      mhv_credential.present? && (added_ivc_only? || added_avc_only?)
    end

    # When the newly added verified_credential_at is the only one that exists and
    # the user has a dslogon credential it is from dslogon e.g. user_avc_updater.dslogon.{added_type}.added
    def from_dslogon?
      dslogon_credential.present? && (added_ivc_only? || added_avc_only?)
    end

    def from_idme?
      # When an avc is added on a uavc already having an ivc it is from idme.
      # e.g. user_avc_updater.idme.avc.added
      return user_avc.idme_verified_credential_at.present? if avc_added?

      # When ivc is the only verified_credential_at that exists and it's not from mhv or dslogon,
      # it's from idme e.g. user_avc_updater.idme.ivc.added
      added_ivc_only? && !from_mhv? && !from_dslogon?
    end

    def from_logingov?
      # When an ivc is added on a uavc already having an avc it is from logingov.
      # e.g. user_avc_updater.logingov.ivc.added
      return user_avc.acceptable_verified_credential_at.present? if ivc_added?

      # When avc is the only verified_credential_at that exists and it's not from mhv or dslogon,
      # it's from logingov e.g. user_avc_updater.logingov.avc.added
      added_avc_only? && !from_mhv? && !from_dslogon?
    end

    ##
    # Checks if the newly added ivc is the only verified_credential_at that exists.
    def added_ivc_only?
      ivc_added? && user_avc.acceptable_verified_credential_at.nil?
    end

    ##
    # Checks if the newly added avc is the only verified_credential_at that exists.
    def added_avc_only?
      avc_added? && user_avc.idme_verified_credential_at.nil?
    end
  end
end
