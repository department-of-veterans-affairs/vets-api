# frozen_string_literal: true

require 'rails_helper'
require 'gi/lce/client'
require 'gi/gids_response'

# TO-DO: Replace stubbed data with VCR cassettes after GIDS connection established
describe GI::Lce::Client do
  let(:client) { GI::Lce::Client.new }
  let(:search_data) do
    [
      {
        link: 'lce/certifications/1',
        name: 'Certification Name',
        type: 'certification'
      }
    ]
  end
  let(:institution) { { name: 'Institution' } }
  let(:lcp_data) do
    {
      desc: 'License Name',
      type: 'license',
      tests: [{ name: 'Test Name' }],
      institution: institution,
      officials: [{ title: 'Certifying Official' }]
    }
  end
  let(:exam_data) do
    {
      name: 'Exam Name',
      tests: [{ description: 'Description' }],
      institution: institution
    }
  end

  it 'gets a list of licenses, certifications, exams, and prep courses' do
    search_response = OpenStruct.new(body: { data: search_data })
    allow(client).to receive(:get_lce_search_results_v1).with(type: 'all').and_return(search_response)
    client_response = client.get_lce_search_results_v1(type: 'all').body
    expect(client_response[:data]).to be_an(Array)
  end

  %w[license certification prep].each do |type|
    it "gets #{type} details" do
      details_response = OpenStruct.new(body: { data: lcp_data })
      query_method = :"get_#{type}_details_v1"

      allow(client).to receive(query_method).with(id: '1').and_return(details_response)
      client_response = client.send(query_method, id: '1').body
      expect(client_response[:data]).to be_an(Hash)
      expect(client_response[:data].keys).to contain_exactly(:desc, :type, :tests, :institution, :officials)
    end
  end

  it 'gets exam details' do
    details_response = OpenStruct.new(body: { data: exam_data })

    allow(client).to receive(:get_exam_details_v1).with(id: '1').and_return(details_response)
    client_response = client.get_exam_details_v1(id: '1').body
    expect(client_response[:data]).to be_an(Hash)
    expect(client_response[:data].keys).to contain_exactly(:name, :tests, :institution)
  end
end
