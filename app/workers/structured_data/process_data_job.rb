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

        send_confirmation_email if @claim.form_id == '21P-530'

        # veteran lookup for hit/miss metrics in support of Automation work
        StatsD.increment("#{stats_key}.success", tags: [
                           "relationship:#{relationship_type}",
                           "veteranInMVI:#{veteran&.participant_id}"
                         ])
      end
    rescue
      raise
    end

    def send_confirmation_email
      return if @claim.parsed_form['claimantEmail'].blank?

      facility_name, street_address, city_state_zip = @claim.regional_office
      first_name = @claim.parsed_form.dig('veteranFullName', 'first')
      last_initial = "#{@claim.parsed_form.dig('veteranFullName', 'last')&.first}."

      VANotify::EmailJob.perform_async(
        @claim.parsed_form['claimantEmail'],
        Settings.vanotify.services.va_gov.template_id.burial_claim_confirmation_email_template_id,
        {
          'form_name' => 'Burial Benefit Claim (Form 21P-530)',
          'confirmation_number' => @claim.guid,
          'deceased_veteran_first_name_last_initial' => "#{first_name} #{last_initial}",
          'benefits_claimed' => benefits_claimed,
          'facility_name' => facility_name,
          'street_address' => street_address,
          'city_state_zip' => city_state_zip,
          'first_name' => @claim.parsed_form.dig('claimantFullName', 'first')&.upcase.presence,
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y')
        }
      )
    end

    def benefits_claimed
      claimed = []
      claimed << 'Burial Allowance' if @claim.parsed_form['burialAllowance']
      claimed << 'Plot Allowance' if @claim.parsed_form['plotAllowance']
      claimed << 'Transportation' if @claim.parsed_form['transportation']
      " - #{claimed.join(" \n - ")}"
    end
  end
end
