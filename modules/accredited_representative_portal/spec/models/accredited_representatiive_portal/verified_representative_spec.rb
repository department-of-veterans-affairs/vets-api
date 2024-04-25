# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::VerifiedRepresentative, type: :model do
  describe 'validations' do
    subject { build(:verified_representative) }

    it { is_expected.to validate_presence_of(:ogc_registration_number) }
    it { is_expected.to validate_uniqueness_of(:ogc_registration_number).case_insensitive }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }

    it do
      expect(subject).to allow_value('test@example.com').for(:email)
      expect(subject).not_to allow_value('invalid_email').for(:email)
    end

    describe '#validate_unique_accredited_individual_email' do
      let!(:individual_one) { create(:accredited_individual, email: 'duplicate@example.com') }
      let!(:individual_two) { create(:accredited_individual, email: 'duplicate@example.com') }

      it 'adds an error on the verified representative email if accredited_individual duplicates are found' do
        verified_rep = build(:verified_representative, email: 'duplicate@example.com')
        verified_rep.validate_unique_accredited_individual_email
        expect(verified_rep.errors[:email]).to include(
          AccreditedRepresentativePortal::VerifiedRepresentative::EMAIL_CONFLICT_ERROR_MESSAGE
        )
      end

      it 'does not add an error if the accredited_individual email is unique' do
        verified_rep = build(:verified_representative, email: 'unique@example.com')
        verified_rep.validate_unique_accredited_individual_email
        expect(verified_rep.errors[:email]).to be_empty
      end
    end
  end

  describe '#poa_codes' do
    let(:ogc_registration_number) { '12345' }

    context 'when an AccreditedIndividual with a matching registration number exists' do
      let!(:accredited_individual) do
        create(:accredited_individual, :with_organizations, registration_number: ogc_registration_number)
      end
      let(:verified_representative) do
        create(:verified_representative, ogc_registration_number:)
      end

      it 'returns the correct POA codes' do
        expect(verified_representative.poa_codes).to be_present
        expect(verified_representative.poa_codes).to match_array(accredited_individual.poa_codes)
      end
    end

    context 'when no AccreditedIndividual with a matching registration number exists' do
      let(:verified_representative) do
        create(:verified_representative, ogc_registration_number:)
      end

      it 'returns nil' do
        expect(verified_representative.poa_codes).to be_nil
      end
    end
  end
end
