# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/fixture_helper'

describe VAOS::JwtWrapper do
  subject { VAOS::JwtWrapper.new(user) }

  let(:user) { build(:user, :vaos) }
  let(:rsa_private) { OpenSSL::PKey::RSA.new(read_fixture_file('open_ssl_rsa_private.pem')) }
  # JWT REGEX has 3 base64 url encoded parts (header, payload signature) and more importantly is non empty.
  let(:jwt_regex) { %r{^[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+\.?[A-Za-z0-9\-_.+/=]*$} }

  before do
    # Stub MPI with VAOS-specific profile data
    stub_mpi(build(:mpi_profile,
                   icn: '1012845331V153043',
                   given_names: ['Judy'],
                   family_name: 'Morrison',
                   ssn: '796061976',
                   edipi: '1259897978',
                   gender: 'F',
                   birth_date: '1953-04-01'))
  end

  describe '#token' do
    before do
      allow(File).to receive(:read).and_return(rsa_private)
      time = Time.utc(2021, 9, 13, 19, 30, 11)
      Timecop.freeze(time)
    end

    after { Timecop.return }

    it 'returns a JWT string' do
      expect(subject.token).to be_a(String).and match(jwt_regex)
    end

    context 'with a decoded payload' do
      let(:decoded_payload) { JWT.decode(subject.token, rsa_private.public_key, true, algorithm: 'RS512').first }

      it 'includes a sub from MVI' do
        expect(decoded_payload['sub']).to eq('1012845331V153043')
      end

      it 'includes a firstName from MVI' do
        expect(decoded_payload['firstName']).to eq('Judy')
      end

      it 'includes a lastName from MVI' do
        expect(decoded_payload['lastName']).to eq('Morrison')
      end

      it 'includes a gender DERIVED from MVI' do
        expect(decoded_payload['gender']).to eq('FEMALE')
      end

      it 'includes a dob from MVI' do
        expect(decoded_payload['dob']).to eq('19530401')
      end

      it 'includes a dateOfBirth from MVI' do
        expect(decoded_payload['dateOfBirth']).to eq('19530401')
      end

      it 'includes a edipid from MVI' do
        expect(decoded_payload['edipid']).to eq('1259897978')
      end

      it 'includes a ssn from MVI' do
        expect(decoded_payload['ssn']).to eq('796061976')
      end

      it 'includes a exp(iration) timestamp' do
        expect(decoded_payload['exp']).to eq(Time.now.utc.to_i + 900)
      end

      it 'includes keys' do
        expect(decoded_payload.keys).to contain_exactly(
          'authenticated', 'sub', 'idType', 'iss', 'firstName', 'lastName', 'authenticationAuthority', 'jti', 'nbf',
          'exp', 'sst', 'version', 'gender', 'dob', 'dateOfBirth', 'edipid', 'ssn'
        )
      end
    end
  end
end
