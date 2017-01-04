# frozen_string_literal: true
require 'rails_helper'
require 'common/exceptions'

describe Mvi, skip_mvi: true do
  let(:user) { FactoryGirl.build(:loa3_user) }
  let(:mvi) { Mvi.from_user(user) }
  let(:find_candidate_response) do
    {
      birth_date: '19800101',
      edipi: '1234^NI^200DOD^USDOD^A',
      vba_corp_id: '12345678^PI^200CORP^USVBA^A',
      family_name: 'Smith',
      gender: 'M',
      given_names: %w(John William),
      icn: '1000123456V123456^NI^200M^USVHA^P',
      mhv_ids: ['123456^PI^200MHV^USVHA^A'],
      ssn: '555443333',
      active_status: 'active'
    }
  end

  describe '.from_user' do
    it 'creates an instance with user attributes' do
      expect(mvi.uuid).to eq(user.uuid)
      expect(mvi.user).to eq(user)
    end
  end

  describe '#query' do
    context 'when the cache is empty' do
      context 'with a succesful MVI response' do
        it 'should cache and return the response' do
          allow_any_instance_of(MVI::Service).to receive(:find_candidate).and_return(find_candidate_response)
          expect(mvi.redis_namespace).to receive(:set).once.with(
            user.uuid,
            Oj.dump(
              uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef',
              response: find_candidate_response.merge(status: 'OK')
            )
          )
          expect_any_instance_of(MVI::Service).to receive(:find_candidate).once
          expect(mvi.edipi).to eq(find_candidate_response[:edipi].split('^').first)
          expect(mvi.icn).to eq(find_candidate_response[:icn].split('^').first)
          expect(mvi.mhv_correlation_id).to eq(find_candidate_response[:mhv_ids].first.split('^').first)
          expect(mvi.participant_id).to eq(find_candidate_response[:vba_corp_id].split('^').first)
        end
      end

      context 'when a SOAP::Errors::HTTPError is raised' do
        it 'should log an error message and return status server error' do
          allow_any_instance_of(MVI::Service).to receive(:find_candidate).and_raise(
            SOAP::Errors::HTTPError.new('MVI HTTP call failed', 500)
          )
          expect(Rails.logger).to receive(:error).once.with(/MVI HTTP error code: 500 for user:/)
          expect(mvi.va_profile).to eq(status: Mvi::MVI_RESPONSE_STATUS[:server_error])
        end
      end

      context 'when a SOAP::Errors::ServiceError is raised' do
        it 'should log an error message and return status not found' do
          allow_any_instance_of(MVI::Service).to receive(:find_candidate).and_raise(SOAP::Errors::InvalidRequestError)
          expect(Rails.logger).to receive(:error).once.with(
            /MVI service error: SOAP::Errors::InvalidRequestError for user:/
          )
          expect(mvi.va_profile).to eq(status: Mvi::MVI_RESPONSE_STATUS[:server_error])
        end
      end

      context 'when SOAP::Errors::RecordNotFound is raised' do
        it 'should log an error message and return status not found' do
          allow_any_instance_of(MVI::Service).to receive(:find_candidate).and_raise(
            SOAP::Errors::RecordNotFound.new('not found')
          )
          expect(Rails.logger).to receive(:error).once.with(/MVI record not found for user:/)
          expect(mvi.va_profile).to eq(status: Mvi::MVI_RESPONSE_STATUS[:not_found])
        end
      end
    end

    context 'when there is cached data' do
      it 'returns the cached data' do
        mvi.response = find_candidate_response.merge(status: 'OK')
        mvi.save
        expect_any_instance_of(MVI::Service).to_not receive(:find_candidate)
        expect(mvi.va_profile).to eq(
          birth_date: '19800101',
          family_name: 'Smith',
          gender: 'M',
          given_names: %w(John William),
          status: Mvi::MVI_RESPONSE_STATUS[:ok]
        )
      end
    end
  end

  context 'when all correlation ids have values' do
    before(:each) do
      allow_any_instance_of(MVI::Service).to receive(:find_candidate).and_return(find_candidate_response)
    end
  end

  around do |example|
    ClimateControl.modify MOCK_MVI_SERVICE: 'false' do
      example.run
    end
  end
end
