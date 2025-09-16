# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::ClaimantSerializer, type: :serializer do
  subject do
    described_class.new(
      power_of_attorney_requests:,
      claimant_representative:,
      claimant_profile:
    ).as_json
  end

  let(:address) do
    double(
      city: 'NEW HAVEN',
      state: 'CT',
      postal_code: '12345'
    )
  end

  let(:claimant_profile) do
    double(
      icn: '123498767V234859',
      address:,
      family_name: 'Cooper',
      given_names: ['Steven']
    )
  end
  let!(:poa_request) { create(:power_of_attorney_request) }
  let(:power_of_attorney_requests) { AccreditedRepresentativePortal::PowerOfAttorneyRequest.all }

  let(:claimant_representative) do
    double(
      power_of_attorney_holder: double(name: 'Org Name'),
      claimant_id: '1234'
    )
  end

  around do |example|
    VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney/200_response') do
      example.run
    end
  end

  before do
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
  end

  describe '#city' do
    it 'returns the city name capitalized' do
      expect(subject.dig('data', 'attributes', 'city')).to eq 'New Haven'
    end

    context 'military address' do
      let(:address) do
        double(
          city: 'FPO',
          state: 'AA',
          postal_code: '12345'
        )
      end

      it 'returns the designation unchanged' do
        expect(subject.dig('data', 'attributes', 'city')).to eq 'FPO'
      end
    end
  end
end
