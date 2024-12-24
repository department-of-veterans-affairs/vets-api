# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/claimant_web_service'
require 'bd/bd'

describe ClaimsApi::ClaimantWebService do
  subject do
    described_class.new external_uid: 'xUid', external_key: 'xKey'
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:claims_status_v2_lh_benefits_docs_service_enabled).and_return true
    allow_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
      .to receive(:get_auth_token).and_return('some-value-here')
  end

  describe '#find_poa_by_participant_id' do
    context 'responds appropriately with success' do
      it 'triggers StatsD measurements' do
        VCR.use_cassette('claims_api/bgs/claimant_web_service/find_poa_by_participant_id',
                         allow_playback_repeats: true) do
          allow_any_instance_of(BGS::ClaimantWebService).to receive(:find_poa_by_participant_id).and_return({})
          %w[establish_ssl_connection connection_post parsed_response].each do |event|
            expect { subject.find_poa_by_participant_id('600061742') }
              .to trigger_statsd_measure("api.claims_api.local_bgs.#{event}.duration")
          end
        end
      end

      it '#add_flash' do
        VCR.use_cassette('claims_api/bgs/claimant_web_service/find_poa_by_participant_id') do
          result = subject.add_flash(file_number: '600061742')
          expect(result).to be_a Hash
        end
      end

      it '#add_assigned_flashes' do
        VCR.use_cassette('claims_api/bgs/claimant_web_service/find_poa_by_participant_id') do
          result = subject.find_assigned_flashes('600061742')
          expect(result).to be_a Hash
        end
      end
    end
  end

  describe 'breakers' do
    it 'returns a Bad Gateway' do
      stub_request(:any, "#{Settings.bgs.url}/ClaimantServiceBean/ClaimantWebService").to_timeout
      stub_request(:any, "#{Settings.bgs.url}/ClaimantServiceBean/ClaimantWebService?WSDL").to_timeout
      expect do
        subject.find_poa_by_participant_id('also-does-not-matter')
      end.to raise_error(Common::Exceptions::BadGateway)
    end

    it 'hits breakers' do
      ClaimsApi::LocalBGS.breakers_service.begin_forced_outage!
      expect do
        subject.find_poa_by_participant_id('also-does-not-matter')
      end.to raise_error(Breakers::OutageException)
      ClaimsApi::LocalBGS.breakers_service.end_forced_outage!
    end
  end
end
