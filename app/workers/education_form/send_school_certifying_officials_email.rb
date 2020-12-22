# frozen_string_literal: true

require 'evss/gi_bill_status/service'

module EducationForm
  class SendSchoolCertifyingOfficialsEmail
    include Sidekiq::Worker

    def perform(user_uuid, claim_id)
      @user = User.find(user_uuid)
      @claim = SavedClaim::EducationBenefits::VA10203.find(claim_id)

      @claim.email_sent(false)

      @gi_bill_status = get_gi_bill_status
      if less_than_six_months?
        @facility_code = get_facility_code

        if @facility_code.present?
          @institution = get_institution

          send_sco_email
        end
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

    def get_gi_bill_status
      service = EVSS::GiBillStatus::Service.new(@user)
      service.get_gi_bill_status
    rescue => e
      Rails.logger.error "Failed to retrieve GiBillStatus data: #{e.message}"
      {}
    end

    def get_facility_code
      most_recent = @gi_bill_status.enrollments.max_by(&:begin_date)

      return {} if most_recent.blank?

      most_recent.facility_code
    end

    def get_institution
      GIDSRedis.new.get_institution_details({ id: @facility_code })[:data][:attributes]
    end

    def less_than_six_months?
      return false if @gi_bill_status.remaining_entitlement.blank?

      months = @gi_bill_status.remaining_entitlement.months
      days = @gi_bill_status.remaining_entitlement.days

      ((months * 30) + days) <= 180
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
        if Flipper.enabled?(:stem_applicant_email, @user)
          StemApplicantScoMailer.build(@claim.open_struct_form, nil).deliver_now
        end
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
