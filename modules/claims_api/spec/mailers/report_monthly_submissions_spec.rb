# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::SubmissionReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      from = 1.month.ago
      to = Time.zone.now

      claim = create(:auto_established_claim, :status_established)
      ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT', consumer_label: 'Consumer name here'
      pact_act_submission = ClaimsApi::ClaimSubmission.where(created_at: from..to)

      described_class.build(
        from,
        to,
        pact_act_submission,
        67,
        12,
        112,
        1
      ).deliver_now
    end

    it 'sends the email' do
      expect(subject.subject).to eq('Benefits Claims Monthly Submission Report')
    end

    it 'has the correct HTML in the email' do
      raw_source = subject.body.raw_source.gsub(/\s+/, '')
      expect(raw_source).to include(email_html)
    end

    it 'sends to the right people' do
      expect(subject.to).to eq(
        %w[
          alex.wilson@oddball.io
          austin.covrig@oddball.io
          emily.goodrich@oddball.io
          jennica.stiehl@oddball.io
          kayla.watanabe@adhocteam.us
          matthew.christianson@adhocteam.us
          rockwell.rice@oddball.io
        ]
      )
    end
  end

  # rubocop:disable Metrics/MethodLength
  def email_html
    "<h2>MonthlySubmissions</h2>
    <table>
    <tr>
    <th>Consumer</th>
    <th>DisabilityCompensationsubmissions</th>
    </tr>
    <tr>
    <td>Form526</td>
    <td>67</td>
    </tr>
    </table>
    <table>
    <tr>
    <th>Consumer</th>
    <th>PowerofAttorneysubmissions</th>
    </tr>
    <tr>
    <td>Form2122/2122a</td>
    <td>12</td>
    </tr>
    </table>
    <table>
    <tr>
    <th>Consumer</th>
    <th>IntenttoFilesubmissions</th>
    </tr>
    <tr>
    <td>Form0966</td>
    <td>112</td>
    </tr>
    </table>
    <table>
    <tr>
    <th>Consumer</th>
    <th>EvidenceWaiversubmissions</th>
    </tr>
    <tr>
    <td>Form5133</td>
    <td>1</td>
    </tr>
    </table>".gsub(/\s+/, '')
  end
  # rubocop:enable Metrics/MethodLength
end
