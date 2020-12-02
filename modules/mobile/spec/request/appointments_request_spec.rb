# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'appointments', type: :request do
  include JsonSchemaMatchers

  describe 'GET /mobile/v0/appointments' do
    before { iam_sign_in }

    before(:all) do
      @original_cassette_dir = VCR.configure(&:cassette_library_dir)
      VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
    end

    after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

    context 'with a user has mixed upcoming appointments' do
      before do
        Timecop.freeze(Time.zone.parse('2020-11-01T10:30:00Z'))
        get '/mobile/v0/appointments', headers: iam_headers, params: params
      end

      after { Timecop.return }

      let(:start_date) { Time.now.utc.iso8601 }
      let(:end_date) { (Time.now.utc + 3.months).iso8601 }
      let(:params) { { startDate: start_date, endDate: end_date } }

      it 'returns an ok response' do
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
