# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VirtualAgent.ReportToCxdw', type: :request do
  conversation_id = 'conversation_id'
  icn = 'icn'
  dataverse_uri = 'https://fake2.com'
  expected_token = 'fake_token'

  it 'retrieves a dataverse oauth token' do
    allow(Settings.virtual_agent).to receive_messages(cxdw_app_uri: 'https://fake.com', cxdw_client_id: 'client_id',
                                                      cxdw_client_secret: 'client_secret')
    VCR.use_cassette('virtual_agent_cxdw_oauth_token', record: :none, match_requests_on: [:uri]) do
      access_token = V0::VirtualAgent::ReportToCxdw.new.send(:get_new_token, dataverse_uri)
      expect(access_token).to eq(expected_token)
    end
  end

  it 'posts data to dataverse table' do
    allow(Settings.virtual_agent).to receive(:cxdw_table_prefix).and_return('table_prefix_')
    VCR.use_cassette('virtual_agent_cxdw_post_to_table', record: :none, match_requests_on: [:uri]) do
      response = V0::VirtualAgent::ReportToCxdw.new.send(:send_to_cxdw, dataverse_uri, icn, conversation_id,
                                                         expected_token)
      expect(response.code).to eq('204')
    end
  end

  it 'report_to_cxdw gets token and posts data' do
    @report_service = V0::VirtualAgent::ReportToCxdw.new
    allow(@report_service).to receive(:get_new_token).and_return(expected_token)
    allow(@report_service).to receive(:send_to_cxdw)
    allow(Settings.virtual_agent).to receive(:cxdw_dataverse_uri).and_return(dataverse_uri)

    @report_service.report_to_cxdw(icn, conversation_id)

    expect(@report_service).to have_received(:get_new_token).with(dataverse_uri)
    expect(@report_service).to have_received(:send_to_cxdw).with(dataverse_uri, icn, conversation_id, expected_token)
  end
end
