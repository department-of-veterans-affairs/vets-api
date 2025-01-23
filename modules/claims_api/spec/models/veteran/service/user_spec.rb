# frozen_string_literal: true

require 'rails_helper'

describe Veteran::User do
  context 'initialization' do
    let(:user) do
      ClaimsApi::Veteran.new(
        uuid: '123456789',
        ssn: '123456789',
        first_name: 'Firstname',
        last_name: 'Lastname',
        va_profile: ClaimsApi::Veteran.build_profile('1970-01-01'),
        last_signed_in: Time.now.utc
      )
    end

    let(:org_web_service) { ClaimsApi::OrgWebService }

    it 'initializes from a user' do
      VCR.use_cassette('claims_api/bgs/claimant_web_service/find_poa_by_participant_id') do
        allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
          .and_return({ person_poa_history: { person_poa: [{ begin_dt: Time.zone.now, legacy_poa_cd: '033' }] } })
        veteran = Veteran::User.new(user)
        expect(veteran.power_of_attorney.code).to eq('074')
        expect(veteran.previous_power_of_attorney.code).to eq('033')
      end
    end

    it 'does not bomb out if poa is missing' do
      VCR.use_cassette('claims_api/bgs/claimant_web_service/not_find_poa_by_participant_id') do
        allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
          .and_return({ person_poa_history: nil })
        veteran = Veteran::User.new(user)
        expect(veteran.power_of_attorney).to be_nil
        expect(veteran.previous_power_of_attorney).to be_nil
      end
    end

    it 'provides most recent previous poa' do
      VCR.use_cassette('claims_api/bgs/claimant_web_service/find_poa_by_participant_id') do
        allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
          .and_return({
                        person_poa_history: {
                          person_poa: [
                            { begin_dt: 2.years.ago, legacy_poa_cd: '233' },
                            { begin_dt: 1.year.ago, legacy_poa_cd: '133' },
                            { begin_dt: 3.years.ago, legacy_poa_cd: '333' }
                          ]
                        }
                      })
        veteran = Veteran::User.new(user)
        expect(veteran.previous_power_of_attorney.code).to eq('133')
      end
    end

    it 'does not bomb out if poa history contains a single record' do
      VCR.use_cassette('claims_api/bgs/claimant_web_service/find_poa_by_participant_id') do
        allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
          .and_return({ person_poa_history: { person_poa: { begin_dt: Time.zone.now, legacy_poa_cd: '033' } } })
        veteran = Veteran::User.new(user)
        expect(veteran.power_of_attorney.code).to eq('074')
        expect(veteran.previous_power_of_attorney.code).to eq('033')
      end
    end
  end
end
