# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'
require 'sentry/processor/pii_sanitizer'

RSpec.describe Sentry::Processor::PIISanitizer do
  include SAML::ResponseBuilder

  let(:client) { double('client') }
  let(:processor) { Sentry::Processor::PIISanitizer.new(client) }
  let(:result) { processor.process(data) }

  # These are needed for communicating issues to downstream parties and should not be sanitized
  context 'sanitization exceptions' do
    let(:data) do
      {
        state: 'SOME STATE',
        relay_state: '{"some_json_key": "some_json_value"}',
        RelayState: '{"another_json_key": "another_json_value"}',
        icn: 'SOME ICN VALUE',
        edipi: 'SOME EDIPI VALUE',
        mhv_correlation_id: 'SOME MHV CORRELATION ID'
      }
    end

    it 'sanitizes state' do
      expect(result[:state]).to eq('FILTERED-CLIENTSIDE')
    end

    it 'does not sanitize relay_state case insensitive' do
      expect(result[:relay_state]).to eq('{"some_json_key": "some_json_value"}')
      expect(result[:RelayState]).to eq('{"another_json_key": "another_json_value"}')
    end

    it 'does not sanitize other important fields needed for logging / communicating to downstream partners' do
      expect(result.slice(:icn, :edipi, :mhv_correlation_id)).to eq(
        icn: 'SOME ICN VALUE',
        edipi: 'SOME EDIPI VALUE',
        mhv_correlation_id: 'SOME MHV CORRELATION ID'
      )
    end
  end

  context 'with symbol keys' do
    let(:data) do
      {
        veteran_address: {
          address_line1: 'addr',
          address_line2: 'addr',
          address_line3: 'addr',
          city: 'Las Vegas',
          country: 'USA',
          postal_code: '91823',
          street: '1234 Street St.',
          state: 'NV'
        },
        directDeposit: {
          accountType: 'SAVINGS',
          accountNumber: '6456456456456464',
          routingNumber: '122239982',
          bankName: 'PACIFIC PREMIER BANK'
        },
        zipCode: '12345',
        fileNumber: '123456789',
        json: '{"phone": "5035551234", "postalCode": 97850}',
        array_of_json: ['{"phone": "5035551234", "postalCode": 97850}'],
        gender: 'M',
        phone: '5035551234',
        va_eauth_birthdate: '1945-02-13T00:00:00+00:00',
        va_eauth_gcIds: ['1234567890^NI^200M^USVHA^P|1234567890^NI^200DOD^USDOD^A|1234567890^PI^200BRLS^USVBA^'],
        va_eauth_pnid: '796375555'
      }
    end

    it 'filters zipcode' do
      expect(result[:zipCode]).to eq('FILTERED-CLIENTSIDE')
    end

    it 'filters fileNumber' do
      expect(result[:fileNumber]).to eq('FILTERED-CLIENTSIDE')
    end

    it 'filters address data' do
      result[:veteran_address].each_value { |v| expect(v).to eq('FILTERED-CLIENTSIDE') }
    end

    it 'filters direct deposit data' do
      result[:directDeposit].each_value { |v| expect(v).to eq('FILTERED-CLIENTSIDE') }
    end

    it 'filters gender data' do
      expect(result[:gender]).to eq('FILTERED-CLIENTSIDE')
    end

    it 'filters phone data' do
      expect(result[:phone]).to eq('FILTERED-CLIENTSIDE')
    end

    it 'filters json blobs' do
      expect(result[:json]).to include('FILTERED-CLIENTSIDE')
    end

    it 'filters arrays' do
      expect(result[:array_of_json].first).to include('FILTERED-CLIENTSIDE')
    end

    it 'filters EVSS va_eauth_birthdate data' do
      expect(result[:va_eauth_birthdate]).to eq('FILTERED-CLIENTSIDE')
    end

    it 'filters EVSS va_eauth_gcIds data' do
      expect(result[:va_eauth_gcIds]).to eq(['FILTERED-CLIENTSIDE'])
    end

    it 'filters EVSS va_eauth_pnid data' do
      expect(result[:va_eauth_pnid]).to eq('FILTERED-CLIENTSIDE')
    end
  end

  context 'with string keys' do
    let(:data) do
      {
        'veteranAddress' => {
          'city' => 'Portland',
          'country' => 'USA',
          'postalCode' => '19391',
          'street' => '4321 Street St.',
          'state' => 'OR'
        },
        'json' => '{"gender": "F"}',
        'arrayOfJson' => ['{"phone": "5035551234", "postalCode": 97850}'],
        'gender' => 'F',
        'phone' => '5415551234',
        'va_eauth_birthdate' => '1945-02-13T00:00:00+00:00',
        'va_eauth_gcIds' => ['1234567890^NI^200M^USVHA^P|1234567890^NI^200DOD^USDOD^A|1234567890^PI^200BRLS^USVBA^'],
        'va_eauth_pnid' => '796375555'
      }
    end

    it 'filters address data' do
      result['veteranAddress'].each_value { |v| expect(v).to eq('FILTERED-CLIENTSIDE') }
    end

    it 'filters gender data' do
      expect(result['gender']).to eq('FILTERED-CLIENTSIDE')
    end

    it 'filters phone data' do
      expect(result['phone']).to eq('FILTERED-CLIENTSIDE')
    end

    it 'filters json blobs' do
      expect(result['json']).to include('FILTERED-CLIENTSIDE')
    end

    it 'filters arrays' do
      expect(result['arrayOfJson'].first).to include('FILTERED-CLIENTSIDE')
    end

    it 'filters EVSS va_eauth_birthdate data' do
      expect(result['va_eauth_birthdate']).to eq('FILTERED-CLIENTSIDE')
    end

    it 'filters EVSS va_eauth_gcIds data' do
      expect(result['va_eauth_gcIds']).to eq(['FILTERED-CLIENTSIDE'])
    end

    it 'filters EVSS va_eauth_pnid data' do
      expect(result['va_eauth_pnid']).to eq('FILTERED-CLIENTSIDE')
    end
  end

  context 'saml_response attributes' do
    context 'handles array values' do
      let(:data) do
        {
          dslogon_assurance: ['2'],
          dslogon_birth_date: ['1984-02-10'],
          dslogon_deceased: ['false'],
          dslogon_fname: ['Bill'],
          dslogon_gender: ['M'],
          dslogon_idtype: ['ssn'],
          dslogon_idvalue: ['333224444'],
          dslogon_lname: ['Walsh'],
          dslogon_mname: ['Brady'],
          dslogon_status: ['VETERAN'],
          dslogon_uuid: ['11111111111'],
          email: ['whatever@whatever.com'],
          level_of_assurance: [0],
          multifactor: [true],
          uuid: ['7ff6f2e7ac774ddc835sdfkjhsdflkj']
        }
      end

      it 'correctly filters pii from saml response attributes' do
        expect(result)
          .to eq(
            dslogon_assurance: ['2'],
            dslogon_birth_date: ['FILTERED-CLIENTSIDE'],
            dslogon_deceased: ['false'],
            dslogon_fname: ['FILTERED-CLIENTSIDE'],
            dslogon_gender: ['FILTERED-CLIENTSIDE'],
            dslogon_idtype: ['ssn'],
            dslogon_idvalue: ['FILTERED-CLIENTSIDE'],
            dslogon_lname: ['FILTERED-CLIENTSIDE'],
            dslogon_mname: ['FILTERED-CLIENTSIDE'],
            dslogon_status: ['VETERAN'],
            dslogon_uuid: ['11111111111'],
            email: ['whatever@whatever.com'],
            level_of_assurance: [0],
            multifactor: [true],
            uuid: ['7ff6f2e7ac774ddc835sdfkjhsdflkj']
          )
      end
    end

    context 'handles an empty array' do
      let(:data) { { 'dslogon_idvalue' => [] } }

      it 'does not filter since no value present' do
        expect(result['dslogon_idvalue']).to eq([])
      end
    end

    context 'handles an array with a blank value or nil value' do
      let(:data) { { 'dslogon_idvalue' => ['', nil] } }

      it 'filters blank and nil differently' do
        expect(result['dslogon_idvalue']).to eq(%w[FILTERED-CLIENTSIDE-BLANK FILTERED-CLIENTSIDE-NIL])
      end
    end

    context 'handles an array with mixed values' do
      let(:data) { { 'dslogon_idvalue' => ['ssn', '', nil, ['ssn', nil], []] } }

      it 'filters blank, nil, and empty array differently' do
        expect(result['dslogon_idvalue']).to eq([
                                                  'FILTERED-CLIENTSIDE',
                                                  'FILTERED-CLIENTSIDE-BLANK',
                                                  'FILTERED-CLIENTSIDE-NIL',
                                                  %w[FILTERED-CLIENTSIDE FILTERED-CLIENTSIDE-NIL],
                                                  []
                                                ])
      end
    end
  end
end
