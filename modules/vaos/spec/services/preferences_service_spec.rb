# frozen_string_literal: true

require 'rails_helper'

describe VAOS::PreferencesService do
  let(:user) { build(:user, :mhv) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_preferences' do
    context 'with a 200 response' do
      it 'includes' do
        VCR.use_cassette('vaos/preferences/get_preferences', match_requests_on: %i[method uri]) do
          response = subject.get_preferences(user)
          expect(response.notification_frequency).to eq('Never')
          expect(response.email_allowed).to be_truthy
          expect(response.email_address).to eq('abraham.lincoln@va.gov')
          expect(response.text_msg_allowed).to be_falsey
        end
      end
    end
  end
end
