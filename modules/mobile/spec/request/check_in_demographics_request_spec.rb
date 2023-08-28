# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'

RSpec.describe 'check in demographics', type: :request do
  before do
    allow_any_instance_of(User).to receive(:vha_facility_hash).and_return({
                                                                            '516' => ['12345'],
                                                                            '553' => ['2'],
                                                                            '200HD' => ['12345'],
                                                                            '200IP' => ['TKIP123456'],
                                                                            '200MHV' => ['123456']
                                                                          })
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')

    iam_sign_in(build(:iam_user))
  end

  describe 'GET /mobile/v0/appointments/check-in/demographics' do
    context 'test' do
      it 'returns expected check in demographics data' do
        VCR.use_cassette('mobile/check_in/token_200') do
          VCR.use_cassette('mobile/check_in/get_demographics_200') do
            get '/mobile/v0/appointments/check-in/demographics', headers: iam_headers,
                                                                 params: { 'location_id' => '516' }
          end
        end
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(
          { 'data' =>
             { 'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
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
        VCR.use_cassette('mobile/check_in/token_200') do
          VCR.use_cassette('mobile/check_in/get_demographics_500') do
            get '/mobile/v0/appointments/check-in/demographics', headers: iam_headers,
                                                                 params: { 'location_id' => '516' }
          end
        end
        expect(response).to have_http_status(:bad_gateway)
        expect(response.parsed_body).to eq({ 'errors' =>
                                  [{ 'title' => 'Bad Gateway',
                                     'detail' =>
                                      'Received an an invalid response from the upstream server',
                                     'code' => 'MOBL_502_upstream_error',
                                     'status' => '502' }] })
      end
    end
  end
end
