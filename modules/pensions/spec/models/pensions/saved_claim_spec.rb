# frozen_string_literal: true

require 'rails_helper'
require 'spec_helper'
require_relative '../../support/saved_claims_spec_helper'

RSpec.describe Pensions::SavedClaim, :uploader_helpers do
  subject { described_class.new }

  let(:instance) { FactoryBot.build(:pensions_module_pension_claim) }

  it_behaves_like 'saved_claim_with_confirmation_number'

  context 'saved claims w/ attachments' do
    stub_virus_scan

    let!(:attachment1) { FactoryBot.create(:pension_burial) }
    let!(:attachment2) { FactoryBot.create(:pension_burial) }

    let(:claim) do
      FactoryBot.create(
        :pensions_module_pension_claim,
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

    it '#send_confirmation_email' do
      allow(VANotify::EmailJob).to receive(:perform_async)
      allow(Settings.vanotify.services.va_gov.template_id).to receive(:form527ez_confirmation_email).and_return(0)

      claim.send_confirmation_email
      claim.send_confirmation_email

      expect(VANotify::EmailJob).to have_received(:perform_async).with(
        'foo@foo.com',
        0,
        {
          'first_name' => 'TEST',
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'confirmation_number' => claim.guid
        }
      ).once
    end
  end

  describe '#email' do
    it 'returns the users email' do
      expect(instance.email).to eq('foo@foo.com')
    end
  end
end
