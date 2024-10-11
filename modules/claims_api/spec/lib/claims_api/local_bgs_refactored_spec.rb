# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/local_bgs_proxy'

describe ClaimsApi::LocalBGSProxy do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  before do
    allow(Flipper).to(
      receive(:enabled?)
        .with(:claims_api_local_bgs_refactor)
        .and_return(true)
    )
  end

  let(:soap_error_handler) { ClaimsApi::LocalBGSRefactored::ErrorHandler }

  describe '#find_poa_by_participant_id' do
    it 'responds as expected, with extra ClaimsApi::Logger logging' do
      VCR.use_cassette('claims_api/bgs/claimant_web_service/find_poa_by_participant_id') do
        # Events logged:
        # 1: built_request - how long to build the request
        # 2: connection_post - how long does the post itself take for the request cycle
        # 3: parsed_response - how long to parse the response
        # 4: transformed_response - how long to transform the response
        expect(ClaimsApi::Logger).to receive(:log).exactly(4).times
        result = subject.find_poa_by_participant_id('does-not-matter')
        expect(result).to be_a Hash
        expect(result[:begin_date]).to eq '09/03/2024'
      end
    end

    describe 'breakers' do
      it 'returns a Bad Gateway' do
        stub_request(:any, "#{Settings.bgs.url}/ClaimantServiceBean/ClaimantWebService").to_timeout
        expect do
          subject.find_poa_by_participant_id('also-does-not-matter')
        end.to raise_error(Common::Exceptions::BadGateway)
      end

      it 'hits breakers' do
        ClaimsApi::BGSClient.breakers_service.begin_forced_outage!
        expect { subject.find_poa_by_participant_id('also-does-not-matter') }.to raise_error(Breakers::OutageException)
        ClaimsApi::BGSClient.breakers_service.end_forced_outage!
      end
    end

    it 'triggers StatsD measurements' do
      VCR.use_cassette('claims_api/bgs/claimant_web_service/find_poa_by_participant_id',
                       allow_playback_repeats: true) do
        %w[built_request connection_post parsed_response transformed_response].each do |event|
          expect { subject.find_poa_by_participant_id('does-not-matter') }
            .to trigger_statsd_measure("api.claims_api.local_bgs.#{event}.duration")
        end
      end
    end
  end

  # Testing potential ways the current check could be tricked
  describe '#all' do
    let(:subject_instance) { subject }
    let(:id) { 12_343 }
    let(:error_message) { { error: 'Did not work', code: 'XXX' } }
    let(:bgs_unknown_error_message) { { error: 'Unexpected error' } }
    let(:empty_array) { [] }

    context 'when an error message gets returned it still does not pass the count check' do
      it 'returns an empty array' do
        expect(error_message.count).to eq(2) # trick the claims count check
        # error message should trigger return
        allow(subject_instance.proxied).to(
          receive(:find_benefit_claims_status_by_ptcpnt_id).with(id).and_return(error_message)
        )
        expect(subject.all(id)).to eq([]) # verify correct return
      end
    end

    context 'when claims come back as a hash instead of an array' do
      it 'casts the hash as an array' do
        VCR.use_cassette('claims_api/bgs/claims/claims_trimmed_down') do
          claims = subject_instance.find_benefit_claims_status_by_ptcpnt_id('600061742')
          claims[:benefit_claims_dto][:benefit_claim] = claims[:benefit_claims_dto][:benefit_claim][0]
          allow(subject_instance.proxied).to(
            receive(:find_benefit_claims_status_by_ptcpnt_id).with(id).and_return(claims)
          )

          begin
            ret = subject_instance.send(:transform_bgs_claims_to_evss, claims)
            expect(ret.class).to_be Array
            expect(ret.size).to eq 1
          rescue => e
            expect(e.message).not_to include 'no implicit conversion of Array into Hash'
          end
        end
      end
    end

    # Already being checked but based on an error seen just want to lock this in to ensure nothing gets missed
    context 'when an empty array gets returned it still does not pass the count check' do
      it 'returns an empty array' do
        # error message should trigger return
        allow(subject_instance.proxied).to(
          receive(:find_benefit_claims_status_by_ptcpnt_id).with(id).and_return(empty_array)
        )
        expect(subject.all(id)).to eq([]) # verify correct return
      end
    end

    context 'when an error message gets returns unknown' do
      it 'the soap error handler returns unprocessable' do
        allow(subject_instance).to receive(:make_request).with(endpoint: 'PersonWebServiceBean/PersonWebService',
                                                               action: 'findPersonBySSN',
                                                               body: Nokogiri::XML::DocumentFragment.new(
                                                                 Nokogiri::XML::Document.new
                                                               ),
                                                               key: 'PersonDTO').and_return(:bgs_unknown_error_message)
        begin
          allow(soap_error_handler).to receive(:handle_errors!)
            .with(:bgs_unknown_error_message).and_raise(Common::Exceptions::UnprocessableEntity)
          ret = soap_error_handler.send(:handle_errors!, :bgs_unknown_error_message)
          expect(ret.class).to_be Array
          expect(ret.size).to eq 1
        rescue => e
          expect(e.message).to include 'Unprocessable Entity'
        end
      end
    end
  end
end
