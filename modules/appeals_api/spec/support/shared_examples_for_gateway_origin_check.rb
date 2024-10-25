# frozen_string_literal: true

shared_examples 'an endpoint requiring gateway origin headers' do |headers:|
  def make_request(_headers = {})
    raise "Pass a block to these shared examples and define a 'make_request' method inside. " \
          'This will allow the shared examples to make a successful request to the endpoint under test.'
  end

  describe '#require_gateway_origin' do
    it 'does nothing by default' do
      make_request(headers)

      expect(response).to have_http_status(:ok)
    end

    context 'with benefits_require_gateway_origin flag on' do
      before do
        allow(Flipper).to receive(:enabled?).with(:benefits_require_gateway_origin).and_return(true)
      end

      it 'does nothing when rails is not running in production mode' do
        make_request(headers)

        expect(response).to have_http_status(:ok)
      end

      context 'when rails runs in production mode' do
        before { allow(Rails.env).to receive(:production?).and_return(true) }

        it 'rejects requests that did not come through the gateway' do
          make_request(headers)

          expect(response).to have_http_status(:unauthorized)
        end

        it 'allows requests that came through the gateway' do
          make_request(headers.merge({
                                       'X-Consumer-Username' => 'some-username',
                                       'X-Consumer-ID' => 'some-id'
                                     }))

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
