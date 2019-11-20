# frozen_string_literal: true

require 'rails_helper'

describe VAOS::UserService do
  let(:user) { build(:user, :mhv) }

  describe '#session' do
    let(:rsa_private) { OpenSSL::PKey::RSA.generate 4096 }
    let(:token) { 'abc123' }
    let(:response) { double('response', body: token) }

    before { allow(File).to receive(:read).and_return(rsa_private) }

    context 'with a 200 response' do
      it 'returns the session token' do
        VCR.use_cassette('vaos/users/post_session') do
          session_token = subject.session(user)
          expect(session_token).to be_a(String)
        end
      end

      context 'with a cached session' do
        it 'does not call the VAOS user service' do
          VCR.use_cassette('vaos/users/post_session') do
            VAOS::SessionStore.new(user_uuid: user.uuid, token: token).save
            expect(subject).not_to receive(:perform)
            subject.session(user)
          end
        end
      end

      context 'when there is no saved session token' do
        it 'makes a call out to the the VAOS user service once' do
          VCR.use_cassette('vaos/users/post_session') do
            expect(subject).to receive(:perform).once.and_return(response)
            subject.session(user)
          end
        end

        it 'returns a token' do
          VCR.use_cassette('vaos/users/post_session') do
            expect(subject.session(user)).to be_a(String)
          end
        end
      end

      context 'when the session is fetched before 15m' do
        it 'does not call perform to request a new token' do
          VAOS::SessionStore.new(user_uuid: user.uuid, token: token).save
          Timecop.travel(Time.zone.now + 11.minutes)
          VCR.use_cassette('vaos/users/post_session') do
            expect(subject).not_to receive(:perform)
            subject.session(user)
          end
          Timecop.return
        end
      end

      context 'when the session is fetched after 15m' do
        it 'calls perform to request a new token' do
          VAOS::SessionStore.new(user_uuid: user.uuid, token: token).save
          Timecop.travel(Time.zone.now + 15.minutes)
          VCR.use_cassette('vaos/users/post_session') do
            expect(subject).to receive(:perform).once.and_return(response)
            subject.session(user)
          end
          Timecop.return
        end
      end
    end

    context 'with a 400 response' do
      it 'raises a client error' do
        VCR.use_cassette('vaos/users/post_session_400') do
          expect { subject.session(user) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'with a 403 response' do
      it 'raises a client error' do
        VCR.use_cassette('vaos/users/post_session_403') do
          expect { subject.session(user) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'with a blank response' do
      it 'raises a client error' do
        VCR.use_cassette('vaos/users/post_session_blank_body') do
          expect { subject.session(user) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
