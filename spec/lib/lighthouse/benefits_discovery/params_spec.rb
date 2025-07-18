# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_discovery/params'

RSpec.describe BenefitsDiscovery::Params do
  subject { described_class.new(user) }

  let(:user) { create(:user, :loa3, :accountable, :legacy_icn) }
  let(:prepared_service_history_params) do
    {
      dischargeStatus: [
        'HONORABLE_DISCHARGE'
      ],
      branchOfService: [
        'ARMY'
      ],
      serviceDates: [
        {
          beginDate: '2012-03-02',
          endDate: '2018-10-31'
        }
      ]
    }
  end

  before do
    allow_any_instance_of(VeteranVerification::Configuration).to receive(:access_token).and_return('token')
  end

  describe '#prepared_params' do
    it 'returns the correct prepared parameters' do
      expected_params = {
        dateOfBirth: '1809-02-12',
        dischargeStatus: ['HONORABLE_DISCHARGE'],
        branchOfService: ['ARMY'],
        disabilityRating: 100,
        serviceDates: [{ beginDate: '2012-03-02', endDate: '2018-10-31' }]
      }

      VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
        expect(subject.prepared_params(prepared_service_history_params)).to eq(expected_params)
      end
    end

    context 'when veteran verification service fails' do
      it 'raises error' do
        VCR.use_cassette('lighthouse/veteran_verification/disability_rating/504_response') do
          expect { subject.prepared_params(prepared_service_history_params) }.to raise_error(Common::Exceptions::GatewayTimeout, 'Gateway timeout')
        end
      end
    end
  end

  describe '.service_history_params' do
    it 'returns params' do
      service_history_episodes = Array.wrap(build(:service_history))
      expect(described_class.service_history_params(service_history_episodes)).to eq(prepared_service_history_params)
    end
  end
end
