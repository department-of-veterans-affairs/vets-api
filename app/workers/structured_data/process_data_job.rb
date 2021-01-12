# frozen_string_literal: true

require 'bip_claims/service'
require 'pension_burial/tag_sentry'

module StructuredData
  class ProcessDataJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    class StructuredDataResponseError < StandardError
    end

    def perform(saved_claim_id)
      begin
        stats_key = BipClaims::Service::STATSD_KEY_PREFIX

        PensionBurial::TagSentry.tag_sentry
        @claim = SavedClaim.find(saved_claim_id)

        relationship_type = @claim.parsed_form['relationship']&.fetch('type', nil)
        veteran = BipClaims::Service.new.lookup_veteran_from_mpi(@claim)
      ensure
        @claim.process_attachments! # upload claim and attachments to Central Mail

        # veteran lookup for hit/miss metrics in support of Automation work
        StatsD.increment("#{stats_key}.success", tags: [
                           "relationship:#{relationship_type}",
                           "veteranInMVI:#{veteran&.participant_id}"
                         ])
      end
    rescue
      raise
    end
  end
end
