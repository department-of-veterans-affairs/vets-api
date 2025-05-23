# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

Rspec.describe 'AppealsApi::V0::Appeals', type: :request do
  describe '#index' do
    include SchemaMatchers

    let(:path) { '/services/appeals/v0/appeals' }

    context 'with the X-VA-SSN and X-VA-User header supplied' do
      let(:user) { create(:user, :loa3) }
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
          get(path, params: nil, headers: user_headers)

          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end

      it 'logs details about the request' do
        VCR.use_cassette('caseflow/appeals') do
          allow(Rails.logger).to receive(:info)
          expect do
            get(path, params: nil, headers: user_headers)
          end.to trigger_statsd_increment(
            'api.external_http_request.CaseflowStatus.success',
            times: 1,
            value: 1,
            tags: array_including(
              'endpoint:/api/v2/appeals',
              'method:get',
              'source:appeals_api'
            )
          )
        end
      end
    end

    context 'with an empty response' do
      let(:user) { create(:user, :loa3) }
      let(:user_headers) do
        {
          'X-VA-SSN' => '111223333',
          'X-Consumer-Username' => 'TestConsumer',
          'X-VA-User' => 'adhoc.test.user'
        }
      end

      it 'returns a successful response' do
        VCR.use_cassette('caseflow/appeals_empty') do
          get(path, params: nil, headers: user_headers)

          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end

    context 'without the X-VA-User header supplied' do
      it 'returns a successful response' do
        VCR.use_cassette('caseflow/appeals') do
          get(path, params: nil, headers: { 'X-VA-SSN' => '111223333', 'X-Consumer-Username' => 'TestConsumer' })
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context 'without the X-VA-SSN header supplied' do
      it 'returns a successful response' do
        VCR.use_cassette('caseflow/appeals') do
          get(path, params: nil, headers: { 'X-Consumer-Username' => 'TestConsumer', 'X-VA-User' => 'adhoc.test.user' })
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context 'with a not found response' do
      it 'returns a 404 and logs an info level message' do
        VCR.use_cassette('caseflow/not_found') do
          get(
            path,
            params: nil,
            headers: {
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

    context 'with a response where "aod" is null instead of a boolean' do
      it 'returns a successful response' do
        VCR.use_cassette('caseflow/appeals_null_aod') do
          get(
            path,
            params: nil,
            headers: {
              'X-VA-SSN' => '111223333',
              'X-Consumer-Username' => 'TestConsumer',
              'X-VA-User' => 'adhoc.test.user'
            }
          )
          expect(response).to have_http_status(:ok)
        end
      end
    end

    it_behaves_like 'an endpoint requiring gateway origin headers',
                    headers: {
                      'X-VA-First-Name' => 'Jane',
                      'X-VA-Last-Name' => 'Doe',
                      'X-VA-SSN' => '123456789',
                      'X-VA-Birth-Date' => '1969-12-31',
                      'X-VA-User' => 'test.user@test.com'
                    } do
      def make_request(headers)
        VCR.use_cassette('caseflow/appeals') do
          get(path, params: nil, headers:)
        end
      end
    end
  end
end
