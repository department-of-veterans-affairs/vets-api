# frozen_string_literal: true

require 'gi/client'

module EducationForm
  class SendSchoolCertifyingOfficialsEmail
    include Sidekiq::Job

    def perform(claim_id, less_than_six_months, facility_code)
      @claim = SavedClaim::EducationBenefits::VA10203.find(claim_id)

      @claim.email_sent(false)

      if less_than_six_months && facility_code.present?
        @institution = get_institution(facility_code)

        send_sco_email
      end
    end

    def self.sco_emails(scos)
      emails = []
      primary = scos.find { |sco| sco[:priority] == 'Primary' && sco[:email].present? }
      secondary = scos.find { |sco| sco[:priority] == 'Secondary' && sco[:email].present? }

      emails.push(primary[:email]) if primary.present?
      emails.push(secondary[:email]) if secondary.present?

      emails
    end

    private

    def get_institution(facility_code)
      GI::Client.new.get_institution_details_v0({ id: facility_code }).body[:data][:attributes]
    rescue Common::Exceptions::RecordNotFound
      StatsD.increment("#{stats_key}.skipped.institution_not_approved")
      nil
    end

    def school_changed?
      application = @claim.parsed_form
      form_school_name = application['schoolName']
      form_school_city = application['schoolCity']
      form_school_state = application['schoolState']

      prefill_name = @institution[:name]
      prefill_city = @institution[:city]
      prefill_state = @institution[:state]

      form_school_name != prefill_name ||
        form_school_city != prefill_city ||
        form_school_state != prefill_state
    end

    def send_sco_email
      return if @institution.blank? || school_changed?

      emails = recipients

      if emails.any?
        StatsD.increment("#{stats_key}.success")
        SchoolCertifyingOfficialsMailer.build(@claim.open_struct_form, emails, nil).deliver_now
        StemApplicantScoMailer.build(@claim.open_struct_form, nil).deliver_now
        @claim.email_sent(true)
      else
        StatsD.increment("#{stats_key}.failure")
      end
    end

    def recipients
      scos = @institution[:versioned_school_certifying_officials]
      EducationForm::SendSchoolCertifyingOfficialsEmail.sco_emails(scos)
    end

    def stats_key
      'api.education_benefits_claim.22-10203.school_certifying_officials_mailer'
    end
  end
end
