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
        consumer_claims_totals: claims_totals,
        poa_totals:,
        ews_totals:,
        itf_totals:
      ).deliver_now
    end

    it 'sends the email' do
      expect(subject.subject).to eq('Benefits Claims Monthly Submission Report')
    end

    shared_examples 'check_email_content' do |email_html|
      it "has the correct #{email_html} HTML in the email" do
        expect(@raw_source).to include(send("#{email_html}_email_html"))
      end
    end

    # Use the shared example for each type of email content
    describe 'Email Content Checks' do
      before do
        @raw_source = subject.body.raw_source.gsub(/\s+/, '')
      end

      include_examples 'check_email_content', 'claims'
      include_examples 'check_email_content', 'poa'
      include_examples 'check_email_content', 'ews'
      include_examples 'check_email_content', 'itf'
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

  def claims_totals
    [
      { 'consumer 1' => { pending: 2,
                          errored: 1,
                          totals: 3 } },
      { 'consumer 2' => { pending: 3,
                          errored: 3,
                          totals: 6 } }
    ]
  end

  # rubocop:disable Metrics/MethodLength
  def claims_email_html
    "
    <table>
      <thead>
        <tr>
          <th>consumer</th>
          <th>pending</th>
          <th>submitted</th>
          <th>established</th>
          <th>errored</th>
          <th>totals</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <tdclass=\"left-align\">consumer1 </td>
          <tdclass=\"right-align\">2 </td>
          <tdclass=\"right-align\">0 </td>
          <tdclass=\"right-align\">0 </td>
          <tdclass=\"right-align\">1 </td>
          <tdclass=\"right-align\">3 </td>
        </tr>
        <tr>
          <tdclass=\"left-align\">consumer2 </td>
          <tdclass=\"right-align\">3 </td>
          <tdclass=\"right-align\">0 </td>
          <tdclass=\"right-align\">0 </td>
          <tdclass=\"right-align\">3 </td>
          <tdclass=\"right-align\">6 </td>
        </tr>
      </tbody>
    </table>
    ".gsub(/\s+/, '')
  end
  # rubocop:enable Metrics/MethodLength

  def poa_totals
    [
      {
        'consumer 3' => { totals: 10, updated: 5, errored: 2, pending: 1, uploaded: 2 }
      },
      {
        'consumer 4' => { totals: 8, updated: 3, errored: 2, pending: 1, uploaded: 2 }
      }
    ]
  end

  # rubocop:disable Metrics/MethodLength
  def poa_email_html
    "
    <table>
      <thead>
        <tr>
          <th>consumer</th>
          <th>pending</th>
          <th>submitted</th>
          <th>uploaded</th>
          <th>updated</th>
          <th>errored</th>
          <th>totals</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <tdclass=\"left-align\">consumer3 </td>
          <tdclass=\"right-align\">1 </td>
          <tdclass=\"right-align\">0 </td>
          <tdclass=\"right-align\">2 </td>
          <tdclass=\"right-align\">5 </td>
          <tdclass=\"right-align\">2 </td>
          <tdclass=\"right-align\">10 </td>
        </tr>
        <tr>
          <tdclass=\"left-align\">consumer4 </td>
          <tdclass=\"right-align\">1 </td>
          <tdclass=\"right-align\">0 </td>
          <tdclass=\"right-align\">2 </td>
          <tdclass=\"right-align\">3 </td>
          <tdclass=\"right-align\">2 </td>
          <tdclass=\"right-align\">8 </td>
        </tr>
      </tbody>
    </table>
    ".gsub(/\s+/, '')
  end
  # rubocop:enable Metrics/MethodLength

  def ews_totals
    [
      {
        'consumer 5' => { totals: 10, updated: 5, errored: 2, pending: 1, uploaded: 2 }
      },
      {
        'consumer 6' => { totals: 8, updated: 3, errored: 2, pending: 1, uploaded: 2 }
      }
    ]
  end

  # rubocop:disable Metrics/MethodLength
  def ews_email_html
    "
    <table>
      <thead>
        <tr>
          <th>consumer</th>
          <th>pending</th>
          <th>uploaded</th>
          <th>updated</th>
          <th>errored</th>
          <th>totals</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <tdclass=\"left-align\">consumer5 </td>
          <tdclass=\"right-align\">1 </td>
          <tdclass=\"right-align\">2 </td>
          <tdclass=\"right-align\">5 </td>
          <tdclass=\"right-align\">2 </td>
          <tdclass=\"right-align\">10 </td>
        </tr>
        <tr>
          <tdclass=\"left-align\">consumer6 </td>
          <tdclass=\"right-align\">1 </td>
          <tdclass=\"right-align\">2 </td>
          <tdclass=\"right-align\">3 </td>
          <tdclass=\"right-align\">2 </td>
          <tdclass=\"right-align\">8 </td>
        </tr>
      </tbody>
    </table>
    ".gsub(/\s+/, '')
  end
  # rubocop:enable Metrics/MethodLength

  def itf_totals
    [
      {
        'consumer 7' => { totals: 2, submitted: 1, errored: 1 }
      },
      {
        'consumer 8' => { totals: 1, submitted: 1, errored: 0 }
      }
    ]
  end

  # rubocop:disable Metrics/MethodLength
  def itf_email_html
    "
    <table>
      <thead>
        <tr>
          <th>consumer</th>
          <th>submitted</th>
          <th>errored</th>
          <th>totals</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <tdclass=\"left-align\">consumer7 </td>
          <tdclass=\"right-align\">1 </td>
          <tdclass=\"right-align\">1 </td>
          <tdclass=\"right-align\">2 </td>
        </tr>
        <tr>
          <tdclass=\"left-align\">consumer8 </td>
          <tdclass=\"right-align\">1 </td>
          <tdclass=\"right-align\">0 </td>
          <tdclass=\"right-align\">1 </td>
        </tr>
      </tbody>
    </table>
    ".gsub(/\s+/, '')
  end
  # rubocop:enable Metrics/MethodLength
end
