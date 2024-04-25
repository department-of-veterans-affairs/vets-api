# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::VerifiedRepresentative, type: :model do
  describe 'validations' do
    subject { build(:verified_representative) }

    it { is_expected.to validate_presence_of(:ogc_registration_number) }
    it { is_expected.to validate_uniqueness_of(:ogc_registration_number).case_insensitive }
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }

    it do
      expect(subject).to allow_value('test@example.com').for(:email)
      expect(subject).not_to allow_value('invalid_email').for(:email)
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
