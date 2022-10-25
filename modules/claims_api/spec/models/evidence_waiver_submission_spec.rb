# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::EvidenceWaiverSubmission, type: :model do
  describe 'requiring fields' do
    context "when 'auth_headers' is not provided" do
      it 'fails validation' do
        ews = ClaimsApi::EvidenceWaiverSubmission.new(encrypted_kms_key: 'bgdhjs')

        expect(ews.valid?).to be(false)
      end
    end

    context "when 'cid' is not provided" do
      it 'fails validation' do
        ews = ClaimsApi::EvidenceWaiverSubmission.new(auth_headers: 'cghdsjg',
                                                      encrypted_kms_key: 'bgdhjs')
        expect(ews.valid?).to be(false)
      end
    end

    context 'when all required attributes are provided' do
      it 'saves the record' do
        ews = ClaimsApi::EvidenceWaiverSubmission.create!(auth_headers: 'cghdsjg',
                                                          encrypted_kms_key: 'bgdhjs', cid: '21635')

        expect { ews.save! }.not_to raise_error
      end
    end
  end
end
