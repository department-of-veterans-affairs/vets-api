# frozen_string_literal: true

require 'rails_helper'

describe VAOS::PreferencesService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :mhv) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_preferences' do
    context 'with a 200 response' do
      it 'includes' do
        VCR.use_cassette('vaos/preferences/get_preferences', match_requests_on: %i[method uri]) do
          response = subject.get_preferences
          expect(response.notification_frequency).to eq('Never')
          expect(response.email_allowed).to be_truthy
          expect(response.email_address).to eq('abraham.lincoln@va.gov')
          expect(response.text_msg_allowed).to be_falsey
        end
      end
    end
  end

  describe '#put_preferences' do
    let(:user) { build(:user, :vaos) }
    let(:request_body) do
      {
        notification_frequency: 'Each new message',
        email_allowed: true,
        email_address: 'abraham.lincoln@va.gov',
        text_msg_allowed: false,
        text_msg_ph_number: ''
      }
    end

    context 'with valid params' do
      it 'updates preferences', :skip_mvi do
        VCR.use_cassette('vaos/preferences/put_preferences', match_requests_on: %i[method uri]) do
          response = subject.put_preferences(request_body)

          expect(response.notification_frequency).to eq('Each new message')
          expect(response.email_allowed).to be_truthy
          expect(response.email_address).to eq('abraham.lincoln@va.gov')
          expect(response.text_msg_allowed).to be_falsey
        end
      end
    end

    context 'with invalid params' do
      it 'returns a validation exception', :skip_mvi do
        expect { subject.put_preferences({}) }.to raise_error(Common::Exceptions::ValidationErrors)
      end
    end
  end
end
