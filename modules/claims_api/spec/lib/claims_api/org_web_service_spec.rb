# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/org_web_service'
require 'bd/bd'

describe ClaimsApi::OrgWebService do
  subject do
    described_class.new external_uid: 'xUid', external_key: 'xKey'
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:claims_status_v2_lh_benefits_docs_service_enabled).and_return true
    allow_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
      .to receive(:get_auth_token).and_return('some-value-here')
  end

  it 'response with the correct namespace' do
    VCR.use_cassette('claims_api/bgs/org_web_service/find_poa_history_by_ptcpnt_id') do
      result = subject.find_poa_history_by_ptcpnt_id('600061742')
      expect(result).to be_a Hash
    end
  end

  it 'triggers StatsD measurements' do
    VCR.use_cassette('claims_api/bgs/org_web_service/find_poa_history_by_ptcpnt_id',
                     allow_playback_repeats: true) do
      allow_any_instance_of(BGS::OrgWebService).to receive(:find_poa_history_by_ptcpnt_id).and_return({})
      %w[establish_ssl_connection connection_post parsed_response].each do |event|
        expect { subject.find_poa_history_by_ptcpnt_id('600061742') }
          .to trigger_statsd_measure("api.claims_api.local_bgs.#{event}.duration")
      end
    end
  end
end
