# frozen_string_literal: true

require 'rails_helper'
require 'gi/lce/client'
require 'gi/gids_response'

# TO-DO: Update with VCR cassettes after GIDS connection established
describe GI::Lce::Client do
  let(:client) { GI::Lce::Client.new}
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:search_data) do
    [
      {
        link: 'lce/certifications/1',
        name: 'Certification Name',
        type: 'certification'
      }
    ]
  end
  let(:institution) do
    {
      name: 'Institution',
      abbreviated_name: 'INST',
      physical_street: 'address',
      physical_city: 'city',
      physical_state: 'state',
      physical_zip: 'zip',
      physical_country: 'USA',
      mailing_street: 'address',
      mailing_city: 'city',
      mailing_state: 'state',
      mailing_zip: 'zip',
      mailing_country: 'USA',
      phone: 'phone',
      web_address: 'website'
    }
  end
  let(:license_details) do
    {
      desc: 'License Name',
      type: 'license',
      tests: [{ name: 'License Test', fee: 30 }],
      institution: institution,
      officials: [{ name: 'Official Name', title: 'Certifying Official'}]
    }
  end
  let(:exam_details) do
    {
      name: 'Exam Name',
      tests: [{ description: 'Description', dates: 'dates', amount: 100 }],
      institution: institution
    }
  end

  it 'gets a list of licenses, certifications, exams, and prep courses' do
    allow(client).to receive(:get_lce_search_results_v1).with(type: 'all').and_return(faraday_response)
    allow(faraday_response).to receive(:body).and_return(data: search_data)
    client_response = client.get_lce_search_results_v1(type: 'all').body
    expect(client_response[:data]).to be_an(Array)
  end

  %w[license certification prep].each do |type|
    it "gets #{type} details" do
      query_method = "get_#{type}_details_v1".to_sym

      allow(client).to receive(query_method).with(id: '1').and_return(faraday_response)
      allow(faraday_response).to receive(:body).and_return(data: license_details)
      client_response = client.send(query_method, id: '1').body
      expect(client_response[:data]).to be_an(Hash)
      expect(client_response[:data].keys).to contain_exactly(:desc, :type, :tests, :institution, :officials)
    end
  end

  it 'gets exam details' do
    allow(client).to receive(:get_exam_details_v1).with(id: '1').and_return(faraday_response)
    allow(faraday_response).to receive(:body).and_return(data: exam_details)
    client_response = client.get_exam_details_v1(id: '1').body
    expect(client_response[:data]).to be_an(Hash)
    expect(client_response[:data].keys).to contain_exactly(:name, :tests, :institution)
  end
end
