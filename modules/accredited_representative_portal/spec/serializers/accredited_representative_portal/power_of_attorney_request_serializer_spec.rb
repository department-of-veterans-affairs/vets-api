# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestSerializer, type: :serializer do
  let(:veteran_declined_resolution) do
    create(:power_of_attorney_request_resolution, :declination, :with_veteran_claimant)
  end
  let(:veteran_declined_poa_request) { veteran_declined_resolution.power_of_attorney_request }
  let(:veteran_declined_power_of_attorney_holder) { veteran_declined_poa_request.power_of_attorney_holder }
  let(:veteran_declined_response) { described_class.new(veteran_declined_poa_request) }
  let(:veteran_declined_data) { veteran_declined_response.serializable_hash }

  let(:dependent_expiration_resolution) do
    create(:power_of_attorney_request_resolution, :expiration, :with_dependent_claimant)
  end
  let(:dependent_expiration_poa_request) { dependent_expiration_resolution.power_of_attorney_request }
  let(:dependent_expiration_response) { described_class.new(dependent_expiration_poa_request) }
  let(:dependent_expiration_data) { dependent_expiration_response.serializable_hash }

  let(:pending_individual_poa_request) { create(:power_of_attorney_request) }

  describe 'PowerOfAttorneyRequestSerializer' do
    it 'includes :id' do
      expect(veteran_declined_data[:id]).to eq veteran_declined_poa_request.id
    end

    it 'includes :claimant_id' do
      expect(veteran_declined_data[:claimant_id]).to eq veteran_declined_poa_request.claimant_id
    end

    it 'includes :created_at' do
      expect(veteran_declined_data[:created_at]).to eq veteran_declined_poa_request.created_at
    end

    it 'includes :expires_at' do
      expect(veteran_declined_data[:expires_at]).to eq veteran_declined_poa_request.expires_at.as_json
    end

    describe ':power_of_attorney_form' do
      it 'modifies claimant key based on claimant type for veteran type' do
        veteran_declined_serialized_form = veteran_declined_data[:power_of_attorney_form]

        expect(veteran_declined_serialized_form['claimant']).to be_present
        expect(veteran_declined_serialized_form).not_to be_key('dependent')
        expect(veteran_declined_serialized_form).not_to be_key('veteran')
      end

      it 'modifies claimant key based on claimant type for dependent type' do
        dependent_expiration_serialized_form = dependent_expiration_data[:power_of_attorney_form]

        expect(dependent_expiration_serialized_form['claimant']).to be_present
        expect(dependent_expiration_serialized_form).not_to be_key('dependent')
        expect(dependent_expiration_serialized_form).to be_key('veteran')
      end
    end

    describe ':resolution' do
      context 'when there is a resolution of type Decision' do
        it 'includes the decision resolution' do
          veteran_declined_resolution_data = veteran_declined_data[:resolution]
          expect(veteran_declined_resolution_data[:type]).to eq 'decision'
          expect(veteran_declined_resolution_data[:decision_type]).to eq 'declination'
          expect(veteran_declined_resolution_data[:reason]).to eq "Didn't authorize treatment record disclosure"
          expect(veteran_declined_resolution_data[:id]).to eq veteran_declined_resolution.id
          expect(veteran_declined_resolution_data[:creator_id]).to eq veteran_declined_resolution.resolving.creator_id
        end
      end

      context 'when there is a resolution of type Expiration' do
        it 'includes the expiration resolution' do
          resolution_data = dependent_expiration_data[:resolution]
          expect(resolution_data[:type]).to eq 'expiration'
        end
      end

      context 'when there is no resolution' do
        it 'is nil' do
          pending_individual_response = described_class.new(pending_individual_poa_request)
          pending_individual_resolution_data = pending_individual_response.serializable_hash[:resolution]
          expect(pending_individual_resolution_data).to be_nil
        end
      end
    end

    describe ':power_of_attorney_holder' do
      context 'when the holder is an AccreditedOrganization' do
        it 'serializes the accredited organization' do
          veteran_declined_holder_data = veteran_declined_data[:power_of_attorney_holder]
          expect(veteran_declined_holder_data[:type]).to eq 'veteran_service_organization'
          expect(veteran_declined_holder_data[:name]).to be_nil
          expect(veteran_declined_holder_data[:id]).to eq veteran_declined_power_of_attorney_holder.id
        end
      end
    end
  end
end
