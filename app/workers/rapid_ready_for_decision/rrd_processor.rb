# frozen_string_literal: true

module RapidReadyForDecision
  class RrdProcessor
    attr_reader :form526_submission

    def initialize(form526_submission)
      @form526_submission = form526_submission
      @disability_struct = RapidReadyForDecision::Constants.first_disability(form526_submission)
    end

    def run
      assessed_data = assess_data
      return if assessed_data.nil?

      add_medical_stats(assessed_data)

      pdf = generate_pdf(assessed_data)
      upload_pdf(pdf)

      set_special_issue if Flipper.enabled?(:rrd_add_special_issue)
    end

    # Return nil to discontinue processing (i.e., doesn't generate pdf or set special issue)
    def assess_data
      raise "Method `assess_data` should be overriden by the subclass #{self.class}"
    end

    # assessed_data is results from assess_data
    def generate_pdf(_assessed_data)
      # This should call a general PDF generator so that subclasses don't need to override this
      raise "Method `generate_pdf` should be overriden by the subclass #{self.class}"
    end

    # Override this method to prevent the submission from getting the PDF and special issue
    def release_pdf?
      flipper_symbol = "rrd_#{@disability_struct[:flipper_name].downcase}_release_pdf".to_sym
      return true unless Flipper.exist?(flipper_symbol)

      Flipper.enabled?(flipper_symbol)
    end

    def upload_pdf(pdf)
      RapidReadyForDecision::FastTrackPdfUploadManager
        .new(form526_submission)
        .handle_attachment(pdf.render, add_to_submission: release_pdf?)
    end

    def set_special_issue
      return unless release_pdf?

      RapidReadyForDecision::RrdSpecialIssueManager.new(form526_submission).add_special_issue
    end

    # Override this method to add to form526_submission.form_json['rrd_metadata']['med_stats']
    def med_stats_hash(_assessed_data); end

    # @param assessed_data [Hash] results from assess_data
    def add_medical_stats(assessed_data)
      med_stats_hash = med_stats_hash(assessed_data)
      return if med_stats_hash.blank?

      form526_submission.add_metadata(med_stats: med_stats_hash)
    end

    class AccountNotFoundError < StandardError; end

    private

    def lighthouse_client
      Lighthouse::VeteransHealth::Client.new(icn)
    end

    def patient_info
      form526_submission.full_name.merge(birthdate: form526_submission.auth_headers['va_eauth_birthdate'])
    end

    def icn
      account_records = accounts
      if account_records.blank?
        raise AccountNotFoundError, "for user_uuid: #{form526_submission.user_uuid} or their edipi"
      end

      return account_records.first.icn.presence if account_records.size == 1

      icns = account_records.pluck(:icn).uniq.compact
      # Multiple Account records should have the same ICN
      if icns.size > 1
        message = "Multiple ICNs found for the user '#{form526_submission.user_uuid}': #{icns}"
        form526_submission.send_rrd_alert_email('RRD Multiple ICNs found warning', message)
      end

      icns.first
    end

    def accounts
      account = Account.lookup_by_user_uuid(form526_submission.user_uuid)
      return [account] if account

      edipi = form526_submission.auth_headers['va_eauth_dodedipnid'].presence
      accounts_matching_edipi(edipi)
    end

    # There's no DB constraint that guarantees uniqueness of edipi, so return an array if there are multiple Accounts
    def accounts_matching_edipi(edipi)
      return [] unless edipi

      Account.where(edipi: edipi).order(:id).to_a
    end
  end
end
