# frozen_string_literal: true

# These examples are collected here for reuse with both the
# V0 and V1 (OAuth) endpoints, which should have the same behavior.
shared_examples 'appeals status endpoints' do |opts|
  describe '#index' do
    include SchemaMatchers
    let(:endpoint) { opts[:appeals_endpoint] }
    let(:oauth_scopes) { opts[:oauth_scopes] || [] }

    context 'with the X-VA-SSN and X-VA-User header supplied ' do
      let(:user) { FactoryBot.create(:user, :loa3) }
      let(:user_headers) do
        {
          'X-VA-SSN' => '111223333',
          'X-VA-First-Name' => 'Test',
          'X-VA-Last-Name' => 'Test',
          'X-VA-EDIPI' => 'Test',
          'X-VA-Birth-Date' => '1985-01-01',
          'X-Consumer-Username' => 'TestConsumer',
          'X-VA-User' => 'adhoc.test.user'
        }
      end

      it 'returns a successful response' do
        VCR.use_cassette('caseflow/appeals') do
          with_openid_auth(oauth_scopes) do |auth_header|
            get endpoint, params: nil, headers: auth_header.merge(user_headers)
          end
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end

      it 'logs details about the request' do
        VCR.use_cassette('caseflow/appeals') do
          allow(Rails.logger).to receive(:info)
          expect do
            with_openid_auth(oauth_scopes) do |auth_header|
              get endpoint, params: nil, headers: auth_header.merge(user_headers)
            end
          end.to trigger_statsd_increment('api.external_http_request.CaseflowStatus.success',
                                          times: 1,
                                          value: 1,
                                          tags: ['endpoint:/api/v2/appeals',
                                                 'method:get',
                                                 'source:appeals_api'])

          hash = Digest::SHA2.hexdigest '111223333'
          expect(Rails.logger).to have_received(:info).with('Caseflow Request',
                                                            'va_user' => 'adhoc.test.user',
                                                            'lookup_identifier' => hash)
          expect(Rails.logger).to have_received(:info).with('Caseflow Response',
                                                            'va_user' => 'adhoc.test.user',
                                                            'first_appeal_id' => '1196201',
                                                            'appeal_count' => 3)
        end
      end
    end

    context 'with an empty response' do
      let(:user) { FactoryBot.create(:user, :loa3) }
      let(:user_headers) do
        {
          'X-VA-SSN' => '111223333',
          'X-Consumer-Username' => 'TestConsumer',
          'X-VA-User' => 'adhoc.test.user'
        }
      end

      it 'returns a successful response' do
        VCR.use_cassette('caseflow/appeals_empty') do
          with_openid_auth(oauth_scopes) do |auth_header|
            get endpoint, params: nil, headers: auth_header.merge(user_headers)
          end

          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end

      it 'logs appropriately' do
        VCR.use_cassette('caseflow/appeals_empty') do
          allow(Rails.logger).to receive(:info)
          with_openid_auth(oauth_scopes) do |auth_header|
            get endpoint, params: nil, headers: auth_header.merge(user_headers)
          end

          hash = Digest::SHA2.hexdigest '111223333'
          expect(Rails.logger).to have_received(:info).with('Caseflow Request',
                                                            'va_user' => 'adhoc.test.user',
                                                            'lookup_identifier' => hash)
          expect(Rails.logger).to have_received(:info).with('Caseflow Response',
                                                            'va_user' => 'adhoc.test.user',
                                                            'first_appeal_id' => nil,
                                                            'appeal_count' => 0)
        end
      end
    end

    context 'without the X-VA-User header supplied' do
      it 'returns a successful response' do
        VCR.use_cassette('caseflow/appeals') do
          with_openid_auth(oauth_scopes) do |auth_header|
            get endpoint,
                params: nil,
                headers: auth_header.merge(
                  {
                    'X-VA-SSN' => '111223333',
                    'X-Consumer-Username' => 'TestConsumer'
                  }
                )
          end
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context 'without the X-VA-SSN header supplied' do
      it 'returns a successful response' do
        VCR.use_cassette('caseflow/appeals') do
          with_openid_auth(oauth_scopes) do |auth_header|
            get endpoint,
                params: nil,
                headers: auth_header.merge(
                  {
                    'X-Consumer-Username' => 'TestConsumer',
                    'X-VA-User' => 'adhoc.test.user'
                  }
                )
            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end

    context 'with a not found response' do
      it 'returns a 404 and logs an info level message' do
        VCR.use_cassette('caseflow/not_found') do
          with_openid_auth(oauth_scopes) do |auth_header|
            get endpoint,
                params: nil,
                headers: auth_header.merge(
                  {
                    'X-VA-SSN' => '111223333',
                    'X-Consumer-Username' => 'TestConsumer',
                    'X-VA-User' => 'adhoc.test.user'
                  }
                )
            expect(response).to have_http_status(:not_found)
            expect(response).to match_response_schema('errors')
          end
        end
      end
    end

    if opts[:oauth_scopes].present?
      context 'with oauth' do
        it_behaves_like 'an endpoint with OpenID auth', scopes: opts[:oauth_scopes] do
          def make_request(auth_header)
            VCR.use_cassette('caseflow/appeals') do
              get('/services/appeals/v1/appeals', headers: auth_header.merge(
                { 'X-VA-SSN' => '111223333', 'X-Consumer-Username' => 'TestConsumer', 'X-VA-User' => 'adhoc.test.user' }
              ))
            end
          end
        end
      end
    end
  end
end
