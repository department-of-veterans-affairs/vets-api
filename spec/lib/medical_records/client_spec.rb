# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/client'

describe MedicalRecords::Client do
  before(:all) do
    VCR.use_cassette 'mr_client/session', record: :new_episodes do
      @client ||= begin
        client = MedicalRecords::Client.new(session: { user_id: '11898795' })
        client.authenticate
        client
      end
    end
  end

  let(:client) { @client }

  it 'gets a list of vaccines', :vcr do
    VCR.use_cassette 'mr_client/get_a_list_of_vaccines' do
      vaccine_list = client.list_vaccines(49_006)
      expect(vaccine_list).to be_a(FHIR::Bundle)
    end
  end

  it 'gets a single vaccine', :vcr do
    VCR.use_cassette 'mr_client/get_a_vaccine' do
      vaccine_list = client.get_vaccine(49_432)
      expect(vaccine_list).to be_a(FHIR::Bundle)
    end
  end
end
