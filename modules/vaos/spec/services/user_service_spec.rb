# frozen_string_literal: true

require 'rails_helper'

describe VAOS::UserService do
  let(:user) { build(:user, :mhv) }

  describe '#session' do
    context 'with a saved VAOS session token' do
      it 'does not make a call out to the service' do
        VCR.use_cassette('vaos/users/post_session') do
          response = subject.session(user)
          expect(response.size).to eq(1)
        end
      end
    end

    context 'when there is no saved session token' do
      it 'makes a call out to the service and caches the response' do
        VCR.use_cassette('vaos/users/post_session') do
          response = subject.session(user)
          expect(response.size).to eq(1)
        end
      end
    end
  end
end
