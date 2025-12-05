# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::UnsuccessfulReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      described_class.build(1.day.ago, Time.zone.now, expected_recipients, consumer_claims_totals: [],
                                                                           unsuccessful_claims_submissions: [],
                                                                           unsuccessful_va_gov_claims_submissions: [],
                                                                           poa_totals: [],
                                                                           unsuccessful_poa_submissions: [],
                                                                           ews_totals: [],
                                                                           unsuccessful_evidence_waiver_submissions: [],
                                                                           itf_totals: []).deliver_now
    end

    let(:recipient_loader) { Class.new { include ClaimsApi::ReportRecipientsReader }.new }
    let(:expected_recipients) { recipient_loader.load_recipients('unsuccessful_report_mailer') }

    it 'sends the email' do
      expect(subject.subject).to eq('Benefits Claims Daily Submission Report')
    end

    it 'sends to the right people' do
      expect(subject.to).to match_array(expected_recipients)
    end
  end

  describe 'claims_api/_submission_grouped_table.html.erb', type: :view do
    # Basic test verifying rendering works as expected, providing DD links for GUIDs
    # in unsuccessful_report_mailer.rb
    it 'renders GUIDs as links with correct query params' do
      guid1 = '21a35517-d229-430b-8e6a-31f33f596e54'
      guid2 = '21a35517-d229-430b-8e6a-31f33f596e56'
      # Mock an ActiveRecord::Relation to simulate pluck behavior
      ar_relation = double('ActiveRecord::Relation', pluck: [guid1, guid2])
      group = ['1', ar_relation]
      assign(:claims, [group])

      render partial: 'claims_api/submission_grouped_table', locals: { claims: [group] }

      doc = Nokogiri::HTML(rendered)
      expect(doc.css('td').map(&:text)).to include('1') # 1 is the group
      links = doc.css('a')
      expect(links.map(&:text)).to include(guid1, guid2) # GUIDs are link texts
    end
  end
end
