# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'
require_relative '../../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::Appointments::CheckIn::Demographics', type: :request do
  include CommitteeHelper

  let(:location_id) { '516' }
  let(:patient_dfn) { '12345' }
  let!(:user) do
    sis_user(
      icn: '24811694708759028',
      vha_facility_hash: {
        location_id => [patient_dfn],
        '553' => ['2'],
        '200HD' => ['12345'],
        '200IP' => ['TKIP123456'],
        '200MHV' => ['123456']
      }
    )
  end

  describe 'GET /mobile/v0/appointments/check-in/demographics' do
    context 'test' do
      it 'returns expected check in demographics data' do
        VCR.use_cassette('chip/token/token_200') do
          VCR.use_cassette('chip/authenticated_demographics/get_demographics_200',
                           erb: { patient_dfn:, station_no: location_id }) do
            get '/mobile/v0/appointments/check-in/demographics', headers: sis_headers,
                                                                 params: { 'location_id' => location_id }
          end
        end
        assert_schema_conform(200)
        expect(response.parsed_body).to eq(
          { 'data' =>
             { 'id' => user.uuid,
               'type' => 'checkInDemographics',
               'attributes' =>
                { 'insuranceVerificationNeeded' => false,
                  'needsConfirmation' => true,
                  'mailingAddress' =>
                   { 'street1' => 'Any Street',
                     'street2' => '',
                     'street3' => '',
                     'city' => 'Any Town',
                     'county' => '',
                     'state' => 'WV',
                     'zip' => '999980071',
                     'zip4' => nil,
                     'country' => 'USA' },
                  'residentialAddress' =>
                   { 'street1' => '186 Columbia Turnpike',
                     'street2' => '',
                     'street3' => '',
                     'city' => 'Florham Park',
                     'county' => '',
                     'state' => 'New Mexico',
                     'zip' => '07932',
                     'zip4' => nil,
                     'country' => 'USA' },
                  'homePhone' => '222-555-8235',
                  'officePhone' => '222-555-7720',
                  'cellPhone' => '315-378-9190',
                  'email' => 'payibo6648@weishu8.com',
                  'emergencyContact' =>
                   { 'name' => 'Bryant Richard',
                     'relationship' => 'Brother',
                     'phone' => '310-399-2006',
                     'workPhone' => '708-391-9015',
                     'address' =>
                      { 'street1' => '690 Holcomb Bridge Rd',
                        'street2' => '',
                        'street3' => '',
                        'city' => 'Roswell',
                        'county' => '',
                        'state' => 'Georgia',
                        'zip' => '30076',
                        'zip4' => '',
                        'country' => 'USA' },
                     'needsConfirmation' => true },
                  'nextOfKin' => { 'name' => nil,
                                   'relationship' => nil,
                                   'phone' => nil,
                                   'workPhone' => nil,
                                   'address' =>
                                     { 'street1' => nil,
                                       'street2' => nil,
                                       'street3' => nil,
                                       'city' => nil,
                                       'county' => nil,
                                       'state' => nil,
                                       'zip' => nil,
                                       'zip4' => nil,
                                       'country' => nil },
                                   'needsConfirmation' => true } } } }
        )
      end
    end

    context 'When upstream service returns 500' do
      it 'returns expected error' do
        VCR.use_cassette('chip/token/token_200') do
          VCR.use_cassette('chip/authenticated_demographics/get_demographics_500',
                           erb: { patient_dfn:, station_no: location_id }) do
            get '/mobile/v0/appointments/check-in/demographics', headers: sis_headers,
                                                                 params: { 'location_id' => location_id }
          end
        end
        assert_schema_conform(502)
        expect(response.parsed_body).to eq({ 'errors' =>
                                  [{ 'title' => 'Bad Gateway',
                                     'detail' =>
                                      'Received an an invalid response from the upstream server',
                                     'code' => 'MOBL_502_upstream_error',
                                     'status' => '502' }] })
      end
    end
  end

  describe 'PATCH /mobile/v0/appointments/check-in/demographics' do
    context 'when upstream updates successfully' do
      it 'returns demographic confirmations' do
        VCR.use_cassette('chip/token/token_200') do
          VCR.use_cassette('chip/authenticated_demographics/update_demographics_200') do
            patch '/mobile/v0/appointments/check-in/demographics',
                  headers: sis_headers,
                  params: { 'location_id' => '418',
                            'demographic_confirmations' => { 'contact_needs_update' => false,
                                                             'emergency_contact_needs_update' => true,
                                                             'next_of_kin_needs_update' => false } }
          end
        end
        assert_schema_conform(200)
        expect(response.parsed_body).to eq(
          { 'data' =>
              { 'id' => '5',
                'type' => 'demographicConfirmations',
                'attributes' =>
                  { 'contactNeedsUpdate' => false,
                    'emergencyContactNeedsUpdate' => true,
                    'nextOfKinNeedsUpdate' => false } } }
        )
      end
    end

    context 'when upstream service fails' do
      it 'throws an exception' do
        VCR.use_cassette('chip/token/token_200') do
          VCR.use_cassette('chip/authenticated_demographics/update_demographics_500') do
            patch '/mobile/v0/appointments/check-in/demographics',
                  headers: sis_headers,
                  params: { 'location_id' => '418',
                            'demographic_confirmations' => { 'contact_needs_update' => false,
                                                             'emergency_contact_needs_update' => true,
                                                             'next_of_kin_needs_update' => false } }
          end
        end
        assert_schema_conform(500)
        expect(response.parsed_body).to eq(
          { 'errors' =>
              [
                { 'title' => 'Internal Server Error',
                  'detail' => [{
                    'errors' => [{
                      'status' => '500',
                      'title' => 'Problem getting token from VistA APIs'
                    }]
                  }],
                  'code' => 'CHIP_500',
                  'status' => '500' }
              ] }
        )
      end
    end
  end
end
