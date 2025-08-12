# frozen_string_literal: true

require 'rails_helper'

describe TravelClaim::TravelPayClient do
  subject(:client) { described_class.build(check_in:) }

  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in) { CheckIn::V2::Session.build(data: { uuid: }) }
  let(:conn_double) { instance_double(Faraday::Connection) }

  before do
    allow(Faraday).to receive(:new).and_return(conn_double)
  end

  describe '.build' do
    it 'returns an instance of described_class' do
      expect(client).to be_an_instance_of(described_class)
    end
  end

  describe '#token' do
    context 'when veis auth returns success' do
      let(:token_response) do
        {
          token_type: 'Bearer',
          expires_in: 3599,
          access_token: 'tp-token'
        }
      end
      let(:veis_token_response) { Faraday::Response.new(body: token_response, status: 200) }

      it 'posts to the VEIS path and yields the request' do
        expect(conn_double).to receive(:post)
          .with("/#{Settings.check_in.travel_reimbursement_api_v2.tenant_id}/oauth2/v2.0/token")
          .and_yield(Faraday::Request.new)
          .and_return(veis_token_response)

        expect(client.token).to eq(veis_token_response)
      end

      it 'encodes travel pay client credentials in the request body' do
        fake_req = Faraday::Request.new

        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      travel_pay_client_id: 'tp-id',
                      travel_pay_client_secret: 'tp-secret',
                      scope: 'api://some.scope/.default') do
          expect(conn_double).to receive(:post)
            .with("/#{Settings.check_in.travel_reimbursement_api_v2.tenant_id}/oauth2/v2.0/token")
            .and_yield(fake_req)
            .and_return(veis_token_response)

          client.token
          body = fake_req.body
          expect(body).to include('client_id=tp-id')
          expect(body).to include('client_secret=tp-secret')
          expect(body).to include('grant_type=client_credentials')
        end
      end
    end

    context 'when veis auth returns an error' do
      let(:resp) { Faraday::Response.new(body: { error: 'Unauthorized' }, status: 401) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      it 'logs message and raises exception' do
        allow(conn_double).to receive(:post).and_raise(exception)
        expect { client.token }.to raise_exception(exception)
      end
    end
  end

  describe '#system_access_token' do
    let(:veis_token) { 'veis-access' }

    context 'when v4 system access returns success' do
      let(:ok_resp) { Faraday::Response.new(response_body: { data: { accessToken: 'btsss' } }, status: 200) }

      it 'posts to v4 path with required headers and body' do
        fake_req = OpenStruct.new(options: OpenStruct.new, headers: {}, body: nil)

        expect(conn_double).to receive(:post)
          .with('/api/v4/auth/system-access-token')
          .and_yield(fake_req)
          .and_return(ok_resp)

        resp = client.system_access_token(veis_access_token: veis_token)
        expect(resp).to eq(ok_resp)
        expect(fake_req.headers['Content-Type']).to eq('application/json')
        expect(fake_req.headers['X-Correlation-ID']).to be_a(String)
        expect(fake_req.headers['Authorization']).to eq("Bearer #{veis_token}")
      end
    end

    context 'when v4 system access returns error' do
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, 401, { error: 'Unauthorized' }) }

      it 'logs message and raises exception' do
        allow(conn_double).to receive(:post).and_raise(exception)
        expect { client.system_access_token(veis_access_token: veis_token) }.to raise_exception(exception)
      end
    end
  end
end
