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

  # TO-DO: Remove this context after transition of LTS to 24/7 availability
  describe 'uptime/downtime tests' do
    let(:tz) { ActiveSupport::TimeZone.new(described_class::OPERATING_ZONE) }
    let(:late_time) { tz.parse('1st Feb 2018 23:00:00') }
    let(:early_time) { tz.parse('1st Feb 2018 1:00:00') }
    let(:saturday_time) { tz.parse('3rd Feb 2018 20:00:00') }
    let(:non_dst) { tz.parse('18th Mar 2018 18:00:00') }

    context 'not during daylight savings' do
      before { Timecop.freeze(non_dst) }

      after { Timecop.return }

      it 'calculates at 6am tomorrow' do
        calculated_time = tz.parse(described_class.retry_after_time)
        expect(calculated_time.day).to eq(19)
        expect(calculated_time.hour).to eq(6)
      end
    end

    context 'before operating hours' do
      before { Timecop.freeze(early_time) }

      after { Timecop.return }

      describe '#retry_after_time' do
        it 'calculates at 6am today' do
          calculated_time = tz.parse(described_class.retry_after_time)
          expect(calculated_time.day).to eq(1)
          expect(calculated_time.hour).to eq(6)
        end
      end
    end

    context 'after operating hours' do
      before { Timecop.freeze(late_time) }

      after { Timecop.return }

      describe '#retry_after_time' do
        it 'calculates tomorrow at 6am' do
          calculated_time = tz.parse(described_class.retry_after_time)
          expect(calculated_time.day).to eq(2)
          expect(calculated_time.hour).to eq(6)
        end
      end
    end

    context 'on saturday' do
      before { Timecop.freeze(saturday_time) }

      after { Timecop.return }

      describe '#within_scheduled_uptime?' do
        it 'properly indicates availability' do
          expect(described_class.within_scheduled_uptime?).to eq(false)
        end
      end
    end

    describe '.seconds_until_downtime' do
      context 'during downtime' do
        before { Timecop.freeze(late_time) }

        after { Timecop.return }

        it 'returns 0' do
          expect(described_class.seconds_until_downtime).to eq(0)
        end
      end

      context 'during uptime' do
        before { Timecop.freeze(non_dst) }

        after { Timecop.return }

        it 'returns number of seconds until uptime ends/downtime starts' do
          expect(described_class.seconds_until_downtime).to eq(14_400)
        end
      end
    end
  end
end
