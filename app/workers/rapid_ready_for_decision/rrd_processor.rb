# frozen_string_literal: true

require 'virtual_regional_office/client'

module RapidReadyForDecision
  class RrdProcessor
    attr_reader :form526_submission, :claim_context

    def initialize(form526_submission)
      @claim_context = RapidReadyForDecision::ClaimContext.new(form526_submission)
      @form526_submission = @claim_context.submission
    end

    def run
      use_vro = Flipper.enabled?(:rrd_call_vro_service)
      use_vro ? assess_data_with_vro : assess_data

      unless @claim_context.sufficient_evidence
        return @form526_submission.save_metadata(offramp_reason: 'insufficient_data')
      end

      add_medical_stats

      pdf_body = (use_vro ? generate_pdf_body_with_vro : generate_pdf.render)
      @claim_context.add_metadata(pdf_created: true)
      upload_pdf(pdf_body)

      set_special_issue

      @claim_context.save_metadata
    end

    # Populates @claim_context.assessed_data and sets claim_context.sufficient_evidence
    def assess_data
      raise "Method `assess_data` should be overriden by the subclass #{self.class}"
    end

    # Returns whether or not @claim_context.assessed_data contains sufficient evidence
    def sufficient_evidence?
      raise "Method `sufficient_evidence?` should be overridden by the subclass #{self.class}"
    end

    # Drop-in replacement for `assess_data` using new VRO service
    def assess_data_with_vro
      response = vro_client.assess_claim(
        diagnostic_code: @claim_context.disability_struct[:code],
        claim_submission_id: form526_submission.id,
        veteran_icn: claim_context.user_icn
      )
      claim_context.assessed_data = response.dig('body', 'evidence').transform_keys(&:to_sym)
      claim_context.sufficient_evidence = sufficient_evidence?
    end

    # @claim_context.assessed_data has results from assess_data
    def generate_pdf
      # This should call a general PDF generator so that subclasses don't need to override this
      raise "Method `generate_pdf` should be overriden by the subclass #{self.class}"
    end

    # Drop-in replacement for `generate_pdf.render` using new VRO service
    def generate_pdf_body_with_vro
      vro_client.generate_summary(
        diagnostic_code: claim_context.disability_struct[:code],
        claim_submission_id: form526_submission.id,
        veteran_info: claim_context.patient_info,
        evidence: claim_context.assessed_data
      )
      vro_client.download_summary(claim_submission_id: form526_submission.id).body
    end

    def upload_pdf(pdf)
      RapidReadyForDecision::FastTrackPdfUploadManager.new(@claim_context)
                                                      .handle_attachment(pdf, add_to_submission: true)
    end

    def set_special_issue
      RapidReadyForDecision::RrdSpecialIssueManager.new(@claim_context).add_special_issue
    end

    # Override this method to add to form526_submission.form_json['rrd_metadata']['med_stats']
    def med_stats_hash(_assessed_data); end

    def add_medical_stats
      med_stats_hash = med_stats_hash(@claim_context.assessed_data)
      @claim_context.add_metadata(med_stats: med_stats_hash) if med_stats_hash.present?
    end

    private

    def lighthouse_client
      @lighthouse_client ||= Lighthouse::VeteransHealth::Client.new(@claim_context.user_icn)
    end

    def vro_client
      @vro_client ||= VirtualRegionalOffice::Client.new
    end
  end
end
