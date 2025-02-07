# frozen_string_literal: true

require 'rails_helper'
require 'evss/intent_to_file/response_strategy'
require 'evss/intent_to_file/service'

describe EVSS::IntentToFile::ResponseStrategy do
  # TODO remove this file
  let(:user) { build(:user, :loa3) }
  let(:service) { EVSS::IntentToFile::Service.new(user) }
  let(:faraday_response) { instance_double(Faraday::Response) }
  let(:itf_response) { EVSS::IntentToFile::IntentToFileResponse.new(200, faraday_response) }
  let(:itf_type) { 'compensation' }

  before do
    allow(faraday_response).to receive_messages(status: 200, body: { intent_to_file: {
                                                  'creation_date' => '2017-06-06T17:31:01+0000',
                                                  'expiration_date' => '2018-06-06T17:31:01+0000',
                                                  'id' => '1',
                                                  'participant_id' => 1,
                                                  'source' => 'VETS.GOV',
                                                  'status' => 'active',
                                                  'type' => 'compensation'
                                                } })
  end

  after { Timecop.return }

  describe '#cache_or_service' do
    context 'when the cache is empty' do
      before { allow(service).to receive(:get_active).with(itf_type).and_return(itf_response) }

      context 'with an ITF that does not expire on the current day' do
        before { Timecop.freeze(Date.new(2017, 10, 21)) }

        it 'caches and return the response' do
          expect(subject.redis_namespace).to receive(:set).once
          response = subject.cache_or_service(user.uuid, 'compensation') { service.get_active(itf_type) }
          expect(response).to be_ok
        end
      end

      context 'with an ITF that expires on the current day' do
        before { Timecop.freeze(Date.new(2018, 6, 6)) }

        it 'does not cache and return the response' do
          expect(subject.redis_namespace).not_to receive(:set)
          response = subject.cache_or_service(user.uuid, 'compensation') { service.get_active(itf_type) }
          expect(response).to be_ok
        end
      end
    end

    context 'when there is cached data' do
      before { Timecop.freeze(Date.new(2017, 10, 21)) }

      it 'does not hit service and returns the cached data' do
        subject.cache("#{user.uuid}:compensation", itf_response)
        expect(service).not_to receive(:get_active)
        response = subject.cache_or_service(user.uuid, 'compensation') { service.get_active(itf_type) }
        expect(response).to be_ok
      end
    end
  end
end
