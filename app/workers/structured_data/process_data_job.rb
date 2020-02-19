# frozen_string_literal: true

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

        case @claim.form_id
        when '21P-530'
          ssn, full_name, bday = claim.parsed_form.values_at(
            'veteranSocialSecurityNumber',
            'veteranFullName',
            'veteranDateOfBirth'
          )
        else
          raise ArgumentError, "Unsupported form id: #{claim.form_id}"
        end

        relationship_type = @claim.parsed_form['relationship']&.fetch('type', nil)
        veteran = BipClaims::Service.new.lookup_veteran_from_mvi(@claim)
      ensure
        @claim.process_attachments! # upload claim and attachments to Central Mail

        # veteran lookup for hit/miss metrics in support of Automation work
        StatsD.increment("#{stats_key}.success", tags: ["relationship:#{relationship_type}", "veteranInMVI:#{!!veteran&.participant_id}"])
      rescue
        raise
      end
    end
  end
end
