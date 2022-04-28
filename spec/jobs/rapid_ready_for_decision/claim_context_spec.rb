# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RapidReadyForDecision::ClaimContext do
  let(:claim_context) { described_class.new(submission) }
  let(:submission) { create(:form526_submission, :asthma_claim_for_increase) }

  context 'if there are multiple Account records with the same edipi' do
    subject { claim_context.user_icn }

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
      subject { claim_context.send(:accounts_matching_edipi, edipi) }

      let(:edipi) { nil }

      it 'returns empty array' do
        expect(subject).to eq []
      end
    end
  end
end
