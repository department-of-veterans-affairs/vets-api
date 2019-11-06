# frozen_string_literal: true

require 'rails_helper'

describe VAOS::SystemsService do
  let(:user) { build(:user, :mhv) }
  let(:rsa_private) { OpenSSL::PKey::RSA.generate 4096 }

  before { allow(File).to receive(:read).and_return(rsa_private) }

  describe '#get_systems' do
    context 'with 10 system identifiers' do
      it 'returns an array of size 10' do
        VCR.use_cassette('vaos/users/post_session') do
          VCR.use_cassette('vaos/systems/get_systems', match_requests_on: %i[host path method]) do
            response = subject.get_systems(user)
            expect(response.size).to eq(10)
          end
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/users/post_session') do
          VCR.use_cassette('vaos/systems/get_systems_500', match_requests_on: %i[host path method]) do
            expect { subject.get_systems(user) }.to raise_error(
              Common::Exceptions::BackendServiceException
            )
          end
        end
      end
    end
  end
end
