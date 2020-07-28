# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::Veteran do
  let(:proc_id) { '12345' }
  let(:fixtures_path) { Rails.root.join('spec', 'fixtures', '686c', 'dependents') }
  let(:all_flows_payload) do
    payload = File.read("#{fixtures_path}/all_flows_payload.json")
    JSON.parse(payload)
  end
  let(:user) do
    {
      participant_id: '600061742',
      ssn: '796043735',
      first_name: 'WESLEY',
      last_name: 'FORD',
      external_key: 'abraham.lincoln@vets.gov',
      icn: '14512449011616630'
    }
  end

  let(:formatted_param_response) do
    {
      'first' => 'WESLEY',
      'middle' => nil,
      'last' => 'FORD',
      'veteran_address' => {
        'country_name' => 'USA',
        'address_line1' => '8200 Doby LN',
        'city' => 'Pasadena',
        'state_code' => 'CA',
        'zip_code' => '21122'
      },
      'phone_number' => '1112223333',
      'email_address' => 'foo@foo.com',
      'country_name' => 'USA',
      'address_line1' => '8200 Doby LN',
      'city' => 'Pasadena',
      'state_code' => 'CA',
      'zip_code' => '21122',
      'vet_ind' => 'Y',
      'martl_status_type_cd' => 'OTHER'
    }
  end

  describe '#formatted_params' do
    it 'formats params given a payload' do
      vet = BGSDependents::Veteran.new(proc_id, user)

      expect(vet.formatted_params(all_flows_payload, user)).to eq(formatted_param_response)
    end
  end
end
