# frozen_string_literal: true

require 'rails_helper'
require 'gi/lcpe/client'
require 'gi/gids_response'

# TO-DO: Replace stubbed data with VCR cassettes after GIDS connection established
describe GI::LCPE::Client do
  let(:client) { GI::LCPE::Client.new }
  let(:search_data) do
    [
      {
        link: 'lcpe/lacs/1',
        name: 'Certification Name',
        type: 'certification'
      }
    ]
  end
  let(:lacs_data) do
    {
      desc: 'License Name',
      type: 'license',
      tests: [{ name: 'Test Name' }],
      institution: 'Institution',
      officials: [{ title: 'Certifying Official' }]
    }
  end
  let(:exam_data) do
    {
      name: 'Exam Name',
      tests: [{ description: 'Description' }],
      institution: 'Institution'
    }
  end

  it 'gets a list of licenses, certifications, and prep courses' do
    search_response = OpenStruct.new(body: { data: search_data })
    allow(client).to receive(:get_licenses_and_certs_v1).with(type: 'all').and_return(search_response)
    client_response = client.get_lce_search_results_v1(type: 'all').body
    expect(client_response[:data]).to be_an(Array)
  end

  it 'gets license and certification details' do
    details_response = OpenStruct.new(body: { data: exam_data })
    allow(client).to receive(:get_license_and_cert_details_v1).with(id: '1').and_return(details_response)
    client_response = client.get_license_and_cert_details_v1(id: '1').body
    expect(client_response[:data]).to be_an(Hash)
    expect(client_response[:data].keys).to contain_exactly(:name, :tests, :institution)
  end

  it 'gets exam details' do
    details_response = OpenStruct.new(body: { data: exam_data })
    allow(client).to receive(:get_exam_details_v1).with(id: '1').and_return(details_response)
    client_response = client.get_exam_details_v1(id: '1').body
    expect(client_response[:data]).to be_an(Hash)
    expect(client_response[:data].keys).to contain_exactly(:name, :tests, :institution)
  end
end
