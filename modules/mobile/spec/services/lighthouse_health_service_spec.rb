# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::LighthouseHealth::Service do
  let(:user) { build(:user, icn: '9000682') }
  let(:service) { Mobile::V0::LighthouseHealth::Service.new(user) }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:access_token) do
    'eyJraWQiOiIyWGlHcG5XRjR0U0wtdENPX19zNDZhMGlkd3I1UUd6YVlwTm4xeEZNX1Y4IiwiYWxnIjoiUlMyNTYifQ.' \
      'eyJ2ZXIiOjEsImp0aSI6IkFULnpoUTZHUDFqRjY2T2g3NG9BcFlDaWxLeHZWUFFDck9yM2JISUlJYkk2c2ciLCJpc3M' \
      'iOiJodHRwczovL2RlcHR2YS1ldmFsLm9rdGEuY29tL29hdXRoMi9hdXM4bm0xcTBmN1ZRMGE0ODJwNyIsImF1ZCI6Im' \
      'h0dHBzOi8vc2FuZGJveC1hcGkudmEuZ292L3NlcnZpY2VzL2ZoaXIiLCJpYXQiOjE2MzQ3NDU1NTYsImV4cCI6MTYzN' \
      'Dc0NTg1NiwiY2lkIjoiMG9hZDB4Z2dpcktMZjJnZXIycDciLCJzY3AiOlsibGF1bmNoIiwicGF0aWVudC9JbW11bml6' \
      'YXRpb24ucmVhZCIsImxhdW5jaC9wYXRpZW50IiwicGF0aWVudC9Mb2NhdGlvbi5yZWFkIl0sInN1YiI6IjBvYWQweGd' \
      'naXJLTGYyZ2VyMnA3In0.dTIB2NGaxAJpalS8aK04VBbBRXlbn7YJF032i4Bw-4sjmycEKZJ3208O5tnZnWpFp4MxC0' \
      'oVql3DV7IuhuPNWxJYgdoOTn1RgW6HvevUAc_WAyOFweNUlxHKxFFDN1RXFf-07ufwQNIeLM0MQYDRNuFdHoIMDb_YJ' \
      '1fre6J_b3Ab5Le_fGhmpCMB3BdK1Ki5dmBeE0b2v9foLuornfkSpGbsmmPP1XYUaISLJHfu-0gl_5G4VdFFawqlC2fF' \
      '9MgGLUZg5C6Xn8odDrz_ADJ2W5yNhRDH8qwmxVOL8g5HaDZRaP9GJwmkXSk9Dhk2XPhG89jmtpkp7xyICUU7sh8Onw'
  end
  let(:expected_item) do
    {
      full_url: 'https://sandbox-api.va.gov/services/fhir/v0/r4/Immunization/I2-DVLM364Y226KFCCINORJP7MP5A000000',
      resource: {
        resource_type: 'Immunization',
        id: 'I2-DVLM364Y226KFCCINORJP7MP5A000000',
        meta: {
          last_updated: '2022-11-25T00:00:00Z'
        },
        status: 'completed',
        vaccine_code: {
          coding: [
            {
              system: 'http://hl7.org/fhir/sid/cvx',
              code: '88',
              display: 'VACCINE GROUP: FLU'
            }
          ],
          text: 'Influenza, seasonal, injectable, preservative free'
        },
        patient: {
          reference: 'https://sandbox-api.va.gov/services/fhir/v0/r4/Patient/1012845331V153043',
          display: 'JUDY MORRISON'
        },
        encounter: {
          reference: 'https://sandbox-api.va.gov/services/fhir/v0/r4/Encounter/I2-2L3EXKQSE5DZT5CMC6M7LOXZLU000000'
        },
        occurrence_date_time: '2014-01-26T09:59:25Z',
        primary_source: true,
        location: {
          reference: 'https://sandbox-api.va.gov/services/fhir/v0/r4/Location/I2-2TKGVAXW355BKTBNRE4BP7N7XE000000',
          display: 'TEST VA FACILITY'
        },
        dose_quantity: {
          value: 4.7,
          unit: 'mL',
          system: 'http://unitsofmeasure.org',
          code: 'mL'
        },
        performer: [
          {
            actor: {
              reference: 'https://sandbox-api.va.gov/services/fhir/v0/r4/Practitioner/I2-MET4XF4STMH3G6677HABC6YTDY000000',
              display: 'Dr. Lucas404 Polanco94'
            }
          }
        ],
        note: [
          {
            text: 'Sample Immunization Note.'
          }
        ],
        reaction: [
          {
            detail: {
              display: 'Other'
            }
          }
        ],
        protocol_applied: [
          {
            dose_number_string: 'Series 1'
          }
        ]
      },
      search: {
        mode: 'match'
      }
    }
  end

  before do
    Timecop.freeze(Time.zone.parse('2021-10-20T15:59:16Z'))
    allow_any_instance_of(Mobile::V0::LighthouseAssertion).to receive(:rsa_key).and_return(
      OpenSSL::PKey::RSA.new(rsa_key.to_s)
    )
  end

  after { Timecop.return }

  describe '#get_immunizations' do
    context 'when an access_token is not cached' do
      let!(:response) do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          service.get_immunizations
        end
      end

      it 'caches the token' do
        expect(Mobile::V0::LighthouseSession.get_cached(user).access_token).to eq(access_token)
      end

      it 'returns multiple immunizations' do
        expect(response[:total]).to eq(12)
      end

      it 'returns items as a FHIR Immunization' do
        expect(response[:entry].first).to eq(expected_item)
      end
    end

    context 'with a cached access_token' do
      before do
        allow(Mobile::V0::LighthouseSession).to receive(:get_cached).and_return(
          Mobile::V0::LighthouseSession.new(access_token:, expires_in: 300)
        )
      end

      let!(:response) do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations_cached_token',
                         match_requests_on: %i[method uri]) do
          service.get_immunizations
        end
      end

      it 'returns multiple immunizations' do
        expect(response[:total]).to eq(12)
      end

      it 'returns items as a FHIR Immunization' do
        expect(response[:entry].first).to eq(expected_item)
      end
    end
  end
end
