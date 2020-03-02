# frozen_string_literal: true

module StructuredData
  class ProcessDataJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    class StructuredDataResponseError < StandardError
    end

    def perform(saved_claim_id)
      stats_key = BipClaims::Service::STATSD_KEY_PREFIX

      PensionBurial::TagSentry.tag_sentry
      @claim = SavedClaim.find(saved_claim_id)
      
      begin
        relationship_type = @claim.parsed_form['relationship']&.fetch('type', nil)
        veteran = BipClaims::Service.new.lookup_veteran_from_mvi(@claim)
        attachments = @claim.process_efolder_attachments!
      rescue
        @claim.process_attachments!
      end

      # veteran lookup for hit/miss metrics in support of Automation work
      StatsD.increment("#{stats_key}.success", tags: [
                          "relationship:#{relationship_type}",
                          "veteranInMVI:#{veteran&.participant_id}"
                        ])
    rescue
      raise
    end
  end
end
