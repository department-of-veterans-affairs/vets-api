# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::Pension, uploader_helpers: true do
  subject { described_class.new }
  let(:instance) { FactoryBot.build(:pension_claim) }

  it_should_behave_like 'saved_claim_with_confirmation_number'
  
  context 'saved claims w/ attachments' do
      stub_virus_scan
      let!(:attachment1) { FactoryBot.create(:pension_burial, saved_claim_id: nil) }
      let!(:attachment2) { FactoryBot.create(:pension_burial, saved_claim_id: nil) }

      let(:claim) { FactoryBot.create(
        :pension_claim,
        form: {
          privacyAgreementAccepted: true,
          veteranFullName: {
            first: 'Test',
            last: 'User'
          },
          gender: 'F',
          email: 'foo@foo.com',
          veteranDateOfBirth: '1989-12-13',
          veteranSocialSecurityNumber: '111223333',
          files: [
            {
              confirmationCode: attachment1.guid
            },
            {
              confirmationCode: attachment2.guid
            }
          ],
          veteranAddress: {
            country: 'USA',
            state: 'CA',
            postalCode: '90210',
            street: '123 Main St',
            city: 'Anytown'
          }
        }.to_json
      )}

    describe '#process_attachments!' do
      it 'should set the attachments saved_claim_id' do
        expect(CentralMail::SubmitSavedClaimJob).to receive(:perform_async).with(claim.id)
        claim.process_attachments!
        expect(claim.persistent_attachments.size).to eq(2)
      end
    end

    describe '#destroy' do
      it 'also destroys the persistent_attachments' do
        claim.process_attachments!
        expect { claim.destroy }.to change { PersistentAttachment.count }.by(-2)
      end
    end
  end

  describe '#email' do
    it 'should return the users email' do
      expect(instance.email).to eq('foo@foo.com')
    end
  end
end
