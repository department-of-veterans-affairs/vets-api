# frozen_string_literal: true

module AccreditedRepresentativePortal
  class Monitor < ::Logging::BaseMonitor
    CLAIM_STATS_KEY = 'api.accredited_representative_portal_claim'
    SUBMISSION_STATS_KEY = 'app.accredited_representative_portal.submit_benefits_intake_claim'

    attr_reader :tags, :claim

    def initialize(claim:)
      @claim = claim
      super('accredited-representative-portal')
      @tags = ["form_id:#{form_id}"]
    end

    private

    def service_name
      'accredited-representative-portal'
    end

    def claim_stats_key
      CLAIM_STATS_KEY
    end

    def submission_stats_key
      SUBMISSION_STATS_KEY
    end

    def form_id
      claim.class::PROPER_FORM_ID
    end

    def send_email(claim_id, email_type)
      AccreditedRepresentativePortal::NotificationEmail.new(claim_id).deliver(email_type)
    end
  end
end
