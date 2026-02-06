# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

RSpec.describe Mobile::V0::ClaimsAndAppealsController, type: :controller do
  let(:user) { sis_user(icn: '1008596379V859838') }

  before do
    sign_in_as(user)
  end

  describe '#adapter_for_provider' do
    it 'returns lighthouse adapter for lighthouse provider' do
      adapter = controller.send(:adapter_for_provider, 'lighthouse')

      expect(adapter).to be_a(Mobile::V0::Adapters::LighthouseIndividualClaims)
    end

    it 'returns lighthouse adapter for uppercase LIGHTHOUSE' do
      adapter = controller.send(:adapter_for_provider, 'LIGHTHOUSE')

      expect(adapter).to be_a(Mobile::V0::Adapters::LighthouseIndividualClaims)
    end

    it 'returns nil for non-lighthouse providers' do
      adapter = controller.send(:adapter_for_provider, 'champva')

      expect(adapter).to be_nil
    end

    it 'returns nil for unknown providers' do
      adapter = controller.send(:adapter_for_provider, 'unknown_provider')

      expect(adapter).to be_nil
    end
  end

  describe '#get_claim with adapter routing' do
    let(:claim_id) { '600117255' }

    before do
      allow(Flipper).to receive(:enabled?).with(:cst_multi_claim_provider_mobile, user).and_return(true)
      allow(controller).to receive(:render)
    end

    context 'when provider has an adapter' do
      let(:lighthouse_response) do
        {
          'data' => {
            'id' => claim_id,
            'type' => 'claim',
            'attributes' => { 'claimId' => claim_id }
          }
        }
      end
      let(:parsed_claim) { double('ParsedClaim', id: claim_id) }

      it 'uses the adapter to parse the response' do
        adapter = instance_double(Mobile::V0::Adapters::LighthouseIndividualClaims)
        allow(controller).to receive(:fetch_claim_and_provider).and_return({
                                                                              provider_type: 'lighthouse',
                                                                              claim_response: lighthouse_response
                                                                            })
        allow(controller).to receive(:adapter_for_provider).with('lighthouse').and_return(adapter)
        allow(adapter).to receive(:parse).with(lighthouse_response).and_return(parsed_claim)
        serializer = double('Serializer')
        allow(Mobile::V0::ClaimSerializer).to receive(:new).with(parsed_claim).and_return(serializer)

        controller.get_claim

        expect(adapter).to have_received(:parse).with(lighthouse_response)
        expect(Mobile::V0::ClaimSerializer).to have_received(:new).with(parsed_claim)
      end
    end

    context 'when provider does not have an adapter' do
      let(:champva_response) do
        {
          'id' => claim_id,
          'type' => 'claim',
          'attributes' => { 'claimId' => claim_id }
        }
      end

      it 'uses the response as-is without adapter parsing' do
        allow(controller).to receive(:fetch_claim_and_provider).and_return({
                                                                              provider_type: 'champva',
                                                                              claim_response: champva_response
                                                                            })
        allow(controller).to receive(:adapter_for_provider).with('champva').and_return(nil)
        serializer = double('Serializer')
        allow(Mobile::V0::ClaimSerializer).to receive(:new).with(champva_response).and_return(serializer)

        controller.get_claim

        expect(Mobile::V0::ClaimSerializer).to have_received(:new).with(champva_response)
      end
    end
  end
end
