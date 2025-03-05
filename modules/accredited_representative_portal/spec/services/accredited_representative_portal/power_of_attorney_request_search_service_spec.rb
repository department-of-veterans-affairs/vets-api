# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestSearchService do
  describe('.call') do
    let!(:poa_code) { 'x23' }
    let!(:other_poa_code) { 'z99' }

    let!(:test_user) do
      create(:representative_user, email: 'test@va.gov', icn: '123498767V234859')
    end

    let!(:accredited_individual) do
      create(:user_account_accredited_individual,
             user_account_email: test_user.email,
             user_account_icn: test_user.icn,
             poa_code:)
    end

    let!(:representative) do
      create(:representative,
             :vso,
             representative_id: accredited_individual.accredited_individual_registration_number,
             poa_codes: [poa_code])
    end
    let(:claimant) { create(:user_account, icn: '1008714701V416111') }
    let!(:poa_request) { create(:power_of_attorney_request, claimant:, poa_code:) }
    let!(:other_poa_request) { create(:power_of_attorney_request, poa_code: other_poa_code) }

    let(:poa_requests) { AccreditedRepresentativePortal::PowerOfAttorneyRequest.all }

    context 'search criteria not provided' do
      it 'returns the same poa requests' do
        expect(described_class.new(poa_requests, nil, nil, nil, nil).call).to eq poa_requests
      end
    end

    context 'search criteria incomplete' do
      it 'raises an error' do
        expect { described_class.new(poa_requests, 'a', nil, nil, nil).call }.to raise_error(described_class::Error)
      end
    end

    context 'profile exists' do
      it 'returns data based on name, dob and ssn' do
        VCR.use_cassette('mpi/find_candidate/valid_icn_full') do
          expect(
            described_class.new(poa_requests, 'John', 'Smith', '1980-01-01', '666-66-6666').call
          ).to eq [poa_request]
        end
      end
    end

    context 'profile not found' do
      it 'returns empty' do
        VCR.use_cassette('mpi/find_candidate/icn_not_found') do
          expect(
            described_class.new(poa_requests, 'John', 'Smith', '1980-01-01', '666-66-6666').call
          ).to be_empty
        end
      end
    end
  end
end
