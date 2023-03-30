# frozen_string_literal: true

module RapidReadyForDecision
  class ClaimContext
    attr_reader :submission, :metadata_hash, :disability_struct
    attr_accessor :assessed_data, :sufficient_evidence

    def initialize(form526_submission)
      @submission = form526_submission
      @disability_struct = RapidReadyForDecision::Constants.first_disability(@submission) || {}
      # Pass around metadata_hash so that we write to DB only once
      @metadata_hash = {}
    end

    def add_metadata(md_hash)
      @metadata_hash.deep_merge!(md_hash)
    end

    def save_metadata
      @submission.save_metadata(@metadata_hash)
    end

    def patient_info
      @submission.full_name.merge(birthdate: @submission.auth_headers['va_eauth_birthdate'])
    end

    class AccountNotFoundError < StandardError; end

    def user_icn
      account_records = accounts
      raise AccountNotFoundError, "for user_uuid: #{@submission.user_uuid} or their edipi" if account_records.blank?

      return account_records.first.icn.presence if account_records.size == 1

      icns = account_records.pluck(:icn).uniq.compact
      # Multiple Account records should have the same ICN
      if icns.size > 1
        message = "Multiple ICNs found for the user '#{@submission.user_uuid}': #{icns}"
        @submission.send_rrd_alert_email('RRD Multiple ICNs found warning', message)
      end

      icns.first
    end

    private

    def accounts
      account = Account.lookup_by_user_uuid(@submission.user_uuid)
      return [account] if account

      edipi = @submission.auth_headers['va_eauth_dodedipnid'].presence
      accounts_matching_edipi(edipi)
    end

    # There's no DB constraint that guarantees uniqueness of edipi, so return an array if there are multiple Accounts
    def accounts_matching_edipi(edipi)
      return [] unless edipi

      Account.where(edipi:).order(:id).to_a
    end
  end
end
