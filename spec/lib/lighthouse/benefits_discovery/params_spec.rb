# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_discovery/params'

RSpec.describe BenefitsDiscovery::Params do
  subject { described_class.new(user.uuid) }

  let(:user) { create(:user, :loa3, :accountable, icn: '123498767V234859') }

  before do
    token = 'blahblech'
    allow_any_instance_of(VeteranVerification::Configuration).to receive(:access_token).and_return(token)
  end

  describe '#prepared_params' do
    it 'returns the correct prepared parameters' do
      expected_params = {
        dateOfBirth: '1809-02-12',
        dischargeStatus: ['GENERAL_DISCHARGE'],
        branchOfService: ['ARMY'],
        disabilityRating: 100,
        serviceDates: [{ beginDate: '2002-02-02', endDate: '2008-12-01' }]
      }

      VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          expect(subject.prepared_params).to eq(expected_params)
        end
      end
    end

    context 'when veteran verification service fails' do
      it 'raises error' do
        VCR.use_cassette('lighthouse/veteran_verification/disability_rating/504_response') do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
            expect { subject.prepared_params }.to raise_error(Common::Exceptions::GatewayTimeout, 'Gateway timeout')
          end
        end
      end
    end

    context 'when military personnel request fails' do
      it 'raises error' do
        VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_history_500') do
            expect { subject.prepared_params }.to raise_error(
              Common::Exceptions::BackendServiceException,
              'BackendServiceException: {:source=>"VAProfile::MilitaryPersonnel::Service", :code=>"VET360_CORE100"}'
            )
          end
        end
      end
    end
  end
end
