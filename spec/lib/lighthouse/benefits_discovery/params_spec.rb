# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_discovery/params'

RSpec.describe BenefitsDiscovery::Params do
  subject { described_class.new(user) }

  let(:user) { create(:user, :loa3, :accountable, :legacy_icn) }
  let(:prepared_service_history_params) do
    [{
      startDate: '2012-03-02',
      endDate: '2018-10-31',
      dischargeStatus: 'HONORABLE_DISCHARGE',
      branchOfService: 'ARMY'
    }]
  end

  before do
    allow_any_instance_of(VeteranVerification::Configuration).to receive(:access_token).and_return('token')
  end

  describe '#prepared_params' do
    it 'returns the correct prepared parameters' do
      expected_params = {
        dateOfBirth: '1809-02-12',
        disabilityRating: 100,
        serviceHistory: [{
          startDate: '2002-02-02', endDate: '2008-12-01', dischargeStatus: 'GENERAL_DISCHARGE', branchOfService: 'ARMY'
        }]
      }

      VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          expect(subject.prepared_params).to eq(expected_params)
        end
      end
    end

    it 'omits any missing params' do
      VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200_empty') do
          expect(subject.prepared_params).to eq({
                                                  dateOfBirth: '1809-02-12',
                                                  disabilityRating: 100
                                                })
        end
      end
    end

    context 'when veteran verification service fails' do
      it 'raises error' do
        VCR.use_cassette('lighthouse/veteran_verification/disability_rating/504_response') do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
            expect { subject.prepared_params }.to \
              raise_error(Common::Exceptions::GatewayTimeout, 'Gateway timeout')
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

    context 'when user does not have vet360 access' do
      let(:user) { create(:user, :loa3, :accountable, :legacy_icn, participant_id: nil) }

      it 'does not fetch disability rating' do
        expected_response = {
          dateOfBirth: '1809-02-12',
          serviceHistory: [{
            startDate: '2002-02-02',
            endDate: '2008-12-01',
            dischargeStatus: 'GENERAL_DISCHARGE',
            branchOfService: 'ARMY'
          }]
        }
        expect(VeteranVerification::Service).not_to receive(:new)

        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          expect(subject.prepared_params).to eq(expected_response)
        end
      end
    end

    context 'when user does not have lighthouse access' do
      let(:user) { create(:user, :loa3, :accountable, :legacy_icn, edipi: nil) }

      it 'does not fetch service history' do
        expect(VAProfile::MilitaryPersonnel::Service).not_to receive(:new)

        VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
          expect(subject.prepared_params).to eq({
                                                  dateOfBirth: '1809-02-12',
                                                  disabilityRating: 100
                                                })
        end
      end
    end

    context 'when the discharge code is present but discharge status is not found' do
      it 'raises error' do
        unfound_discharge_history = Array.wrap(build(:service_history, character_of_discharge_code: 'foo'))
        service_history_response = OpenStruct.new episodes: unfound_discharge_history
        allow_any_instance_of(VAProfile::MilitaryPersonnel::Service).to \
          receive(:get_service_history).and_return(service_history_response)
        VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
          expect { subject.prepared_params }.to raise_error(Common::Exceptions::UnprocessableEntity),
                                                { detail: 'No matching discharge type for: foo',
                                                  source: described_class.name }
        end
      end
    end

    context 'when discharge code is blank' do
      it 'sets dischargeStatus to nil' do
        service_history_episodes = Array.wrap(build(:service_history, character_of_discharge_code: nil))
        service_history_response = OpenStruct.new episodes: service_history_episodes
        allow_any_instance_of(VAProfile::MilitaryPersonnel::Service).to \
          receive(:get_service_history).and_return(service_history_response)
        VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
          expect(subject.prepared_params).to eq(
            { dateOfBirth: '1809-02-12', disabilityRating: 100,
              serviceHistory: [
                { startDate: '2012-03-02', endDate: '2018-10-31', dischargeStatus: nil, branchOfService: 'ARMY' }
              ] }
          )
        end
      end
    end
  end

  describe '#build_from_service_history' do
    it 'returns the correct prepared parameters' do
      expected_params = {
        dateOfBirth: '1809-02-12',
        disabilityRating: 100,
        serviceHistory: prepared_service_history_params
      }

      VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
        expect(subject.build_from_service_history(prepared_service_history_params)).to eq(expected_params)
      end
    end

    it 'omits any missing params' do
      VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
        expect(subject.build_from_service_history({})).to eq({
                                                               dateOfBirth: '1809-02-12',
                                                               disabilityRating: 100
                                                             })
      end
    end

    context 'when veteran verification service fails' do
      it 'raises error' do
        VCR.use_cassette('lighthouse/veteran_verification/disability_rating/504_response') do
          expect { subject.build_from_service_history(prepared_service_history_params) }.to \
            raise_error(Common::Exceptions::GatewayTimeout, 'Gateway timeout')
        end
      end
    end
  end

  describe '.service_history_params' do
    it 'returns discharge status, branch of service, and service dates' do
      service_history_episodes = Array.wrap(build(:service_history))
      expect(described_class.service_history_params(service_history_episodes)).to eq(prepared_service_history_params)
    end

    context 'when the discharge code is present but discharge status is not found' do
      it 'raises error' do
        unfound_discharge_history = Array.wrap(build(:service_history, character_of_discharge_code: 'foo'))
        expect do
          described_class.service_history_params(unfound_discharge_history)
        end.to raise_error(Common::Exceptions::UnprocessableEntity), { detail: 'No matching discharge type for: foo', source: described_class.name }
      end
    end

    context 'discharge code is blank' do
      it 'sets dischargeStatus to nil' do
        service_history_episodes = Array.wrap(build(:service_history, character_of_discharge_code: nil))
        expect(described_class.service_history_params(service_history_episodes)).to eq([{
                                                                                         startDate: '2012-03-02',
                                                                                         endDate: '2018-10-31',
                                                                                         dischargeStatus: nil,
                                                                                         branchOfService: 'ARMY'
                                                                                       }])
      end
    end
  end
end
