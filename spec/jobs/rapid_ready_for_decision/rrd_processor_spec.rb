# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe RapidReadyForDecision::RrdProcessor do
  let(:rrd_processor) { described_class.new(submission) }
  let(:submission) { create(:form526_submission, :hypertension_claim_for_increase) }

  describe '#add_medical_stats', :vcr do
    subject { rrd_processor.add_medical_stats(assessed_data) }

    let(:assessed_data) { { somekey: 'someValue' } }

    before { expect(rrd_processor).to receive(:med_stats_hash).and_return({ newkey: 'someValue' }) }

    it 'adds to rrd_metadata.med_stats' do
      subject
      expect(submission.form.dig('rrd_metadata', 'med_stats', 'newkey')).to eq 'someValue'
    end
  end

  describe '#set_special_issue', :vcr do
    subject { rrd_processor.set_special_issue }

    it 'calls add_special_issue' do
      expect_any_instance_of(RapidReadyForDecision::RrdSpecialIssueManager).to receive(:add_special_issue)
      subject
    end
  end

  describe '#release_pdf?' do
    subject { rrd_processor.release_pdf? }

    it 'returns true when Flipper symbol does not exist' do
      Flipper.remove(:rrd_hypertension_release_pdf)
      expect(subject).to eq true
    end
  end

  context 'if there are multiple Account records with the same edipi' do
    subject { rrd_processor.send(:icn) }

    let!(:user) { User.find(submission.user_uuid) }
    let(:account2_icn) { "#{user.account.icn}_different" }

    before do
      create(:account, edipi: user.account.edipi, icn: account2_icn)
      # Force edipi to be used for account lookup
      submission.update(user_uuid: 'that_which_cannot_be_found')
    end

    it 'sends an alert' do
      expect_any_instance_of(Form526Submission).to receive(:send_rrd_alert_email)
      subject
    end

    context 'with the same icn' do
      let(:account2_icn) { user.account.icn }

      it 'finishes successfully' do
        expect(subject).to eq user.account.icn
      end
    end

    describe '#accounts_matching_edipi when va_eauth_dodedipnid is nil' do
      subject { rrd_processor.send(:accounts_matching_edipi, edipi) }

      let(:edipi) { nil }

      it 'returns empty array' do
        expect(subject).to eq []
      end
    end
  end
end
