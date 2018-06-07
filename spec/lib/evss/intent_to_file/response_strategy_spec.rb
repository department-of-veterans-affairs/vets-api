# frozen_string_literal: true

require 'rails_helper'

describe EVSS::IntentToFile::ResponseStrategy do
  let(:user) { build(:user, :loa3) }
  let(:service) { EVSS::IntentToFile::Service.new(user) }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:itf_response) { EVSS::IntentToFile::IntentToFileResponse.new(200, faraday_response) }
  let(:itf_type) { 'compensation' }

  before do
    allow(faraday_response).to receive(:status) { 200 }
    allow(faraday_response).to receive(:body) do
      {
        intent_to_file: {
          'creation_date' => '2017-06-06T17:31:01+0000',
          'expiration_date' => '2018-06-06T17:31:01+0000',
          'id' => '1',
          'participant_id' => 1,
          'source' => 'VETS.GOV',
          'status' => 'active',
          'type' => 'compensation'
        }
      }
    end
  end

  describe '#cache_or_service' do
    context 'when the cache is empty' do
      before(:each) { allow(service).to receive(:get_active).with(itf_type).and_return(itf_response) }

      context 'with an ITF that does not expire on the current day' do
        before { Timecop.freeze(Date.new(2017, 10, 21)) }

        it 'should cache and return the response' do
          expect(subject.redis_namespace).to receive(:set).once
          response = subject.cache_or_service(user.uuid, 'compensation') { service.get_active(itf_type) }
          expect(response).to be_ok
        end
      end

      context 'with an ITF that expires on the current day' do
        before { Timecop.freeze(Date.new(2018, 06, 06)) }

        it 'should not cache and return the response' do
          expect(subject.redis_namespace).to_not receive(:set)
          response = subject.cache_or_service(user.uuid, 'compensation') { service.get_active(itf_type) }
          expect(response).to be_ok
        end
      end

      context 'with an ITF that has expired' do
        before { Timecop.freeze(Date.new(2018, 10, 21)) }

        it 'should not cache and return the response' do
          expect(subject.redis_namespace).to_not receive(:set)
          response = subject.cache_or_service(user.uuid, 'compensation') { service.get_active(itf_type) }
          expect(response).to be_ok
        end
      end
    end

    context 'when there is cached data' do
      xit 'does not hit service and returns the cached data' do
        subject.cache(:countries, countries_response)
        expect(service).to_not receive(:get_countries)
        response = subject.cache_or_service(:countries) { service.get_countries }
        expect(response).to be_ok
      end
    end
  end
end
