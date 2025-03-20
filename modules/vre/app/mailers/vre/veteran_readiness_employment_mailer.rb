# frozen_string_literal: true

module VRE
  class VeteranReadinessEmploymentMailer < ApplicationMailer
    def build(pid, email_addr, routed_to_cmp)
      email_addr = 'kcrawford@governmentcio.com' if FeatureFlipper.staging_email?
      @submission_date = Time.current.in_time_zone('America/New_York').strftime('%m/%d/%Y')
      @pid = pid
      cmp = '_cmp' if routed_to_cmp
      file_path = Rails.root.join('app', 'mailers', 'views', "veteran_readiness_employment#{cmp}.html.erb")
      template = File.read(file_path)

      mail(
        to: email_addr,
        subject: 'VR&E Counseling Request Confirmation', # rubocop:disable Rails/I18nLocaleTexts
        body: ERB.new(template).result(binding)
      )
    end
  end
end
