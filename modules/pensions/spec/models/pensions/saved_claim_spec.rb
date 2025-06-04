# frozen_string_literal: true

require 'rails_helper'
require 'spec_helper'
require_relative '../../support/saved_claims_spec_helper'

RSpec.describe Pensions::SavedClaim, :uploader_helpers do
  subject { described_class.new }

  let(:instance) { build(:pensions_saved_claim) }

  it_behaves_like 'saved_claim_with_confirmation_number'

  context 'saved claims w/ attachments' do
    stub_virus_scan

    let!(:attachment1) { create(:pension_burial) }
    let!(:attachment2) { create(:pension_burial) }

    let(:claim) do
      create(
        :pensions_saved_claim,
        form: {
          veteranFullName: {
            first: 'Test',
            last: 'User'
          },
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
          },
          statementOfTruthCertified: true,
          statementOfTruthSignature: 'Test User'
        }.to_json
      )
    end

    context 'using JSON Schemer' do
      describe '#process_attachments!' do
        it 'sets the attachments saved_claim_id' do
          expect(Lighthouse::SubmitBenefitsIntakeClaim).not_to receive(:perform_async).with(claim.id)
          claim.process_attachments!
          expect(claim.persistent_attachments.size).to eq(2)
        end
      end

      describe '#destroy' do
        it 'also destroys the persistent_attachments' do
          claim.process_attachments!
          expect { claim.destroy }.to change(PersistentAttachment, :count).by(-2)
        end
      end
    end
  end

  describe '#email' do
    it 'returns the users email' do
      expect(instance.email).to eq('foo@foo.com')
    end
  end

  describe '#first_name' do
    it 'returns the users first name' do
      expect(instance.first_name).to eq('Test')
    end
  end
end
