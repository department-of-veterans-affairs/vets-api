# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_discovery/service'

RSpec.describe BenefitsDiscovery::Service do
  subject do
    described_class.new(
      api_key: 'test_api_key',
      app_id: 'test_app_id'
    )
  end

  describe '#get_eligible_benefits' do
    context 'with params' do
      let(:params) do
        {
          dateOfBirth: '2000-06-15',
          dischargeStatus: ['HONORABLE_DISCHARGE'],
          branchOfService: ['NAVY'],
          disabilityRating: 60,
          serviceDates: [{ startDate: '2018-01-01', endDate: '2022-01-01' }]
        }
      end

      it 'returns recommendations' do
        VCR.use_cassette('lighthouse/benefits_discovery/200_response_with_all_params',
                         match_requests_on: %i[method uri body]) do
          response = subject.get_eligible_benefits(params)
          expect(response).to eq(
            {
              'undetermined' => [],
              'recommended' => [
                {
                  'benefit_name' => 'Life Insurance (VALife)',
                  'benefit_url' => 'https://www.va.gov/life-insurance/'
                },
                {
                  'benefit_name' => 'Health',
                  'benefit_url' => 'https://www.va.gov/health-care/'
                }
              ],
              'not_recommended' => []
            }
          )
        end
      end
    end

    context 'with empty values' do
      let(:params) { {} }

      it 'returns recommendations' do
        VCR.use_cassette('lighthouse/benefits_discovery/200_response_without_params',
                         match_requests_on: %i[method uri body]) do
          response = subject.get_eligible_benefits(params)
          expect(response).to eq(
            {
              'undetermined' => [
                {
                  'benefit_name' => 'Health',
                  'benefit_url' => 'https://www.va.gov/health-care/'
                }
              ],
              'recommended' => [],
              'not_recommended' => [{
                'benefit_name' => 'Life Insurance (VALife)',
                'benefit_url' => 'https://www.va.gov/life-insurance/'
              }]
            }
          )
        end
      end
    end

    context 'with invalid param values' do
      let(:params) { { branchOfService: 'A-Team' } }

      it 'raises client error' do
        VCR.use_cassette('lighthouse/benefits_discovery/400_response_with_invalid_params',
                         match_requests_on: %i[method uri body]) do
          expect do
            subject.get_eligible_benefits(params)
          end.to raise_error(Common::Client::Errors::ClientError)
        end
      end
    end
  end

  describe '#proxy_request' do
    let(:mock_post_request) do
      req = ActionDispatch::TestRequest.create
      req.request_method = 'POST'
      req.set_header('CONTENT_TYPE', 'application/json')
      req.remote_addr = '1.2.3.4'
      req.env['action_dispatch.request.request_parameters'] = {}
      req.env['RAW_POST_DATA'] = '{}'
      req.params['path'] = 'v0/recommendations'
      req
    end

    it 'returns recommendations when v0/recommendations is called' do
      VCR.use_cassette('lighthouse/benefits_discovery/200_response_without_params',
                       match_requests_on: %i[method uri body]) do
        response = subject.proxy_request(mock_post_request)
        expect(response).to eq(
          {
            'undetermined' => [
              {
                'benefit_name' => 'Health',
                'benefit_url' => 'https://www.va.gov/health-care/'
              }
            ],
            'recommended' => [],
            'not_recommended' => [{
              'benefit_name' => 'Life Insurance (VALife)',
              'benefit_url' => 'https://www.va.gov/life-insurance/'
            }]
          }
        )
      end
    end

    it 'calls perform with correct arguments and sets X-Forwarded-For' do
      expect(subject).to receive(:perform).with(:post, # rubocop:disable RSpec/SubjectStub
                                                'benefits-discovery-service/v0/recommendations',
                                                '{}',
                                                hash_including('X-Forwarded-For' => '1.2.3.4'))
                                          .and_return(double('response', body: nil))
      subject.proxy_request(mock_post_request)
    end
  end
end
