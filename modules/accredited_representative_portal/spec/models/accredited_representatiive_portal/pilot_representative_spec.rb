# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PilotRepresentative, type: :model do
  let(:arp_pilot_rep) { AccreditedRepresentativePortal::PilotRepresentative }

  before do
    allow(Rails.logger).to receive(:info)
  end

  describe 'validations' do
    subject { build(:pilot_representative) }

    it { is_expected.to validate_presence_of(:ogc_registration_number) }
    it { is_expected.to validate_uniqueness_of(:ogc_registration_number).case_insensitive }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }

    it do
      expect(subject).to allow_value('test@example.com').for(:email)
      expect(subject).not_to allow_value('invalid_email').for(:email)
    end
  end

  describe '#poa_codes' do
    let(:ogc_registration_number) { '12345' }

    context 'when an accredited_individual with a matching registration number exists' do
      let!(:accredited_individual) do
        create(:accredited_individual, :with_organizations, registration_number: ogc_registration_number)
      end
      let(:pilot_representative) do
        create(:pilot_representative, ogc_registration_number:)
      end

      it 'returns the correct POA codes' do
        expect(pilot_representative.poa_codes).to be_present
        expect(pilot_representative.poa_codes).to match_array(accredited_individual.poa_codes)
      end
    end

    context 'when no accredited_individual with a matching registration number exists' do
      let(:pilot_representative) do
        create(:pilot_representative, ogc_registration_number:)
      end

      it 'returns nil and logs' do
        expect(pilot_representative.poa_codes).to be_nil
        expect(Rails.logger).to have_received(:info).with(
          "No matching AccreditedIndividual found for PilotRepresentative ID: #{pilot_representative.id}"
        )
      end
    end

    context 'when no POA codes are available for the given registration number' do
      let!(:accredited_individual) do
        create(:accredited_individual, registration_number: ogc_registration_number, email: 'existing@example.com')
      end
      let(:pilot_representative) do
        create(:pilot_representative, ogc_registration_number:, email: 'existing@example.com')
      end

      it 'logs an info message indicating no matching POA codes' do
        expect(pilot_representative.poa_codes).to be_nil
        expect(Rails.logger).to have_received(:info).with(
          "No matching POA codes for PilotRepresentative ID: #{pilot_representative.id}"
        )
      end
    end

    context 'when an error occurs' do
      before do
        allow(AccreditedIndividual).to receive(:find_by).and_raise(StandardError, 'Something went wrong')
      end

      let(:pilot_representative) do
        create(:pilot_representative, ogc_registration_number:)
      end

      it 'logs the error and returns nil' do
        expect(pilot_representative.poa_codes).to be_nil
        expect(Rails.logger).to have_received(:info).with(
          /Fetching POA codes failed for PilotRepresentative ID: \d+ - .+/
        )
      end
    end

    context 'when logging accredited_individual email matches' do
      let!(:accredited_individual_one) { create(:accredited_individual, email: 'duplicate@example.com') }
      let!(:accredited_individual_two) { create(:accredited_individual, email: 'duplicate@example.com') }
      let!(:accredited_individual_three) { create(:accredited_individual, email: 'unique@example.com') }

      context 'when an accredited_individual email match is not found' do
        let(:pilot_representative) { create(:pilot_representative, email: 'non-existing@example.com') }

        it 'logs that no matching email was found' do
          pilot_representative.poa_codes
          expect(Rails.logger).to have_received(:info).with(arp_pilot_rep::EMAIL_NO_MATCH_MESSAGE).twice
        end
      end

      context 'when an accredited_individual email match is found' do
        let(:pilot_representative) { create(:pilot_representative, email: 'unique@example.com') }

        it 'does not log that no matching email was found' do
          pilot_representative.poa_codes
          expect(Rails.logger).not_to have_received(:info).with(arp_pilot_rep::EMAIL_NO_MATCH_MESSAGE)
        end
      end

      context 'when an accredited_individual email is shared across multiple records' do
        let(:pilot_representative) { create(:pilot_representative, email: 'duplicate@example.com') }

        it 'logs that multiple accredited_individuals have the same email' do
          pilot_representative.poa_codes
          expect(Rails.logger).to have_received(:info).with(
            /#{arp_pilot_rep::EMAIL_MULTIPLE_MATCH_MESSAGE} AccreditedIndividual IDs:/
          ).twice
        end
      end
    end
  end
end
