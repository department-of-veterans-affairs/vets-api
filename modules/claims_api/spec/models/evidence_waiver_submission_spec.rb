# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::EvidenceWaiverSubmission, type: :model do
  describe 'requiring fields' do
    context "when 'auth_headers' is not provided" do
      it 'fails validation' do
        ews = ClaimsApi::EvidenceWaiverSubmission.new

        expect(ews.valid?).to be(false)
      end
    end

    context "when 'cid' is not provided" do
      it { is_expected.to validate_presence_of(:cid) }
    end

    context 'when all required attributes are provided' do
      it 'saves the record' do
        ews = create(:evidence_waiver_submission, auth_headers: 'cghdsjg',
                                                  cid: '21635')

        expect { ews.save! }.not_to raise_error
      end
    end
  end
end
