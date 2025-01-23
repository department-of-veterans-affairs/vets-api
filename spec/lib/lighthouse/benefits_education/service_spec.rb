# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_education/service'

RSpec.describe BenefitsEducation::Service do
  before(:all) do
    icn = '1012667145V762142'
    # icn retrieved from
    # https://github.com/department-of-veterans-affairs/vets-api-clients/blob/master/test_accounts/benefits_test_accounts.md
    @service = BenefitsEducation::Service.new(icn)
  end

  # Veteran's ICN is now considered PII - do not include it
  # in the output of `inspect`
  it 'does not display icn when calling `inspect`' do
    service_inspect = @service.inspect
    expect(service_inspect).not_to include('icn')
  end

  describe 'making requests' do
    context '200' do
      describe '200 success' do
        it 'returns a 200 ok status' do
          # in order to successfully (re)record this request,
          # - remove the existing 200_response.yml file,
          # - edit config/test.yml and set the following values:
          #   - use_mocks: false
          #   - access_token:
          #     - client_id: <your valid client_id>
          #     - rsa_key: <path on your local filesystem>
          # these values are results of a request to get sandbox access:
          # https://developer.va.gov/explore/api/education-benefits
          VCR.use_cassette('lighthouse/benefits_education/200_response') do
            response = @service.get_gi_bill_status

            # assertions that the data returned will match our test user
            expect(response['first_name']).to eq('Tamara')
            expect(response['last_name']).to eq('Ellis')
            expect(response['date_of_birth']).to start_with('1967-06-19')
          end
        end
      end
    end
  end
end
