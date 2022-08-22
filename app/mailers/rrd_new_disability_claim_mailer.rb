# frozen_string_literal: true

class RrdNewDisabilityClaimMailer < ApplicationMailer
  def build(submission, health_data)
    @id = submission.id
    @submitted_claim_id = submission.submitted_claim_id
    @created_at = submission.created_at
    @disabilities = submission.disabilities
    @bp_readings = health_data[:bp_readings_count]
    @medications = health_data[:medications_count]
    @num_issues = submission.disabilities.count

    template = File.read('app/mailers/views/rrd_new_disability_claim_mailer.html.erb')

    mail(
      to: Settings.rrd.pact_tracking.recipients,
      subject: "NEW claim - #{submission.submitted_claim_id}",
      body: ERB.new(template).result(binding)
    )
  end
end
