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
end
