# frozen_string_literal: true

module RapidReadyForDecision
  class RrdProcessor
    attr_reader :form526_submission, :claim_context

    def initialize(form526_submission)
      @claim_context = RapidReadyForDecision::ClaimContext.new(form526_submission)
      @form526_submission = @claim_context.submission
    end

    def run
      assessed_data = assess_data
      return if assessed_data.nil?

      add_medical_stats(assessed_data)

      pdf = generate_pdf(assessed_data)
      @claim_context.add_metadata(pdf_created: true)
      upload_pdf(pdf)

      set_special_issue if Flipper.enabled?(:rrd_add_special_issue) && release_pdf?

      @claim_context.save_metadata
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
      flipper_symbol = "rrd_#{@claim_context.disability_struct[:flipper_name].downcase}_release_pdf".to_sym
      return true unless Flipper.exist?(flipper_symbol)

      Flipper.enabled?(flipper_symbol)
    end

    def upload_pdf(pdf)
      RapidReadyForDecision::FastTrackPdfUploadManager.new(@claim_context)
                                                      .handle_attachment(pdf.render, add_to_submission: release_pdf?)
    end

    def set_special_issue
      RapidReadyForDecision::RrdSpecialIssueManager.new(@claim_context).add_special_issue
    end

    # Override this method to add to form526_submission.form_json['rrd_metadata']['med_stats']
    def med_stats_hash(_assessed_data); end

    # @param assessed_data [Hash] results from assess_data
    def add_medical_stats(assessed_data)
      med_stats_hash = med_stats_hash(assessed_data)
      return if med_stats_hash.blank?

      @claim_context.add_metadata(med_stats: med_stats_hash)
    end

    private

    def lighthouse_client
      Lighthouse::VeteransHealth::Client.new(@claim_context.user_icn)
    end

    def patient_info
      form526_submission.full_name.merge(birthdate: form526_submission.auth_headers['va_eauth_birthdate'])
    end
  end
end
