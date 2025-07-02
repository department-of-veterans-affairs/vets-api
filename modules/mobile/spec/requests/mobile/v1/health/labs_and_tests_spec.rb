# frozen_string_literal: true

require 'rails_helper'
require 'date'

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V1::LabsAndTestsController', :skip_json_api_validation, type: :request do
  # Helper method to sort lab records by dateCompleted in descending order (newest first)
  # Ensure fixture follows the same sorting logic.
  def sort_labs_by_date(labs)
    return [] if labs.blank?

    labs.sort_by do |record|
      date_str = record['dateCompleted'] || record.dig('attributes', 'dateCompleted')
      date_str ? DateTime.parse(date_str).to_time.to_i : 0
    end.reverse
  end
  let!(:user) { sis_user(icn: '1000123456V123456') }
  let(:default_params) { { startDate: '2024-01-01', endDate: '2025-05-31' } }
  let(:path) { '/mobile/v1/health/labs-and-tests' }
  let(:labs_cassette) { 'mobile/unified_health_data/get_labs' }
  let(:labs_attachment_cassette) { 'mobile/unified_health_data/get_labs_value_attachment' }
  let(:uhd_flipper) { :mhv_accelerated_delivery_uhd_enabled }
  let(:ch_flipper) { :mhv_accelerated_delivery_uhd_ch_enabled }
  let(:ch_response) do
    JSON.parse(Rails.root.join(
      'modules', 'mobile', 'spec', 'support', 'fixtures', 'labs_and_tests_ch_response.json'
    ).read)
  end
  let(:sp_flipper) { :mhv_accelerated_delivery_uhd_sp_enabled }
  let(:sp_response) do
    JSON.parse(Rails.root.join(
      'modules', 'mobile', 'spec', 'support', 'fixtures', 'labs_and_tests_sp_response.json'
    ).read)
  end
  let(:mb_flipper) { :mhv_accelerated_delivery_uhd_mb_enabled }
  let(:mb_response) do
    JSON.parse(Rails.root.join(
      'modules', 'mobile', 'spec', 'support', 'fixtures', 'labs_and_tests_mb_response.json'
    ).read)
  rescue Errno::ENOENT
    {} # Return empty hash if the fixture doesn't exist yet
  end

  describe 'GET /mobile/v1/health/labs-and-tests' do
    context 'happy path' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(sp_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(ch_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(mb_flipper, instance_of(User)).and_return(true)
        VCR.use_cassette(labs_cassette) do
          get path, headers: sis_headers, params: default_params
        end
      end

      it 'returns a successful response' do
        expect(response).to be_successful
      end

      it 'returns the correct lab records' do
        json_data = JSON.parse(response.body)
        json_response = json_data['data'] || []

        # Use helper method to sort by dateCompleted
        sorted_response = sort_labs_by_date(json_response)

        expect(sorted_response.count).to eq(18)
        # Check that our test records are included in the response
        # rather than expecting specific indices
        expect(sorted_response).to include(ch_response.first)
        expect(sorted_response).to include(sp_response.first)
        expect(sorted_response).to include(mb_response.first)
      end
    end

    context 'SP only' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(sp_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(ch_flipper, instance_of(User)).and_return(false)
        allow(Flipper).to receive(:enabled?).with(mb_flipper, instance_of(User)).and_return(false)
        VCR.use_cassette(labs_cassette) do
          get path, headers: sis_headers, params: default_params
        end
      end

      it 'returns a successful response' do
        expect(response).to be_successful
      end

      it 'returns the correct lab records' do
        json_data = JSON.parse(response.body)
        json_response = json_data['data'] || []

        # Use helper method to sort by dateCompleted
        sorted_response = sort_labs_by_date(json_response)

        # Check that our SP record is included in the response
        # and CH record is not included
        expect(sorted_response).to include(sp_response.first)
        expect(sorted_response).not_to include(ch_response.first)
        expect(sorted_response).not_to include(mb_response.first)
      end
    end

    context 'CH only' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(sp_flipper, instance_of(User)).and_return(false)
        allow(Flipper).to receive(:enabled?).with(ch_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(mb_flipper, instance_of(User)).and_return(false)
        VCR.use_cassette(labs_cassette) do
          get path, headers: sis_headers, params: default_params
        end
      end

      it 'returns a successful response' do
        expect(response).to be_successful
      end

      it 'returns the correct lab records' do
        json_data = JSON.parse(response.body)
        json_response = json_data['data'] || []

        # Use helper method to sort by dateCompleted
        sorted_response = sort_labs_by_date(json_response)

        # Check that our CH record is included in the response
        # and SP record is not included
        expect(sorted_response).to include(ch_response.first)
        expect(sorted_response).not_to include(sp_response.first)
        expect(sorted_response).not_to include(mb_response.first)
      end
    end

    context 'MB only' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(sp_flipper, instance_of(User)).and_return(false)
        allow(Flipper).to receive(:enabled?).with(ch_flipper, instance_of(User)).and_return(false)
        allow(Flipper).to receive(:enabled?).with(mb_flipper, instance_of(User)).and_return(true)
        VCR.use_cassette(labs_cassette) do
          get path, headers: sis_headers, params: default_params
        end
      end

      it 'returns a successful response' do
        expect(response).to be_successful
      end

      it 'returns the correct lab records' do
        json_data = JSON.parse(response.body)
        json_response = json_data['data'] || []

        # Use helper method to sort by dateCompleted
        sorted_response = sort_labs_by_date(json_response)

        # Check that our MB record is included in the response
        # and SP record is not included
        expect(sorted_response).to include(mb_response.first)
        expect(sorted_response).not_to include(sp_response.first)
        expect(sorted_response).not_to include(ch_response.first)
      end
    end

    context 'when UHD is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(false)
        VCR.use_cassette(labs_cassette) do
          get path, headers: sis_headers, params: default_params
        end
      end

      it 'returns a 404 when the flipper is disabled' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'errors' do
      before do
        allow(Flipper).to receive(:enabled?).with(ch_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(sp_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(mb_flipper, instance_of(User)).and_return(true)
        allow(Rails.logger).to receive(:error)
        VCR.use_cassette(labs_attachment_cassette) do
          get path, headers: sis_headers, params: default_params
        end
      end

      it 'returns not_implemented when a value attachment is received' do
        expect(Rails.logger).to have_received(:error).with(
          { message: 'Observation with ID 4e0a8d43-1281-4d11-97b8-f77452bea53a has unsupported value type: Attachment' }
        )
        expect(response).to have_http_status(:not_implemented)
      end
    end
  end
end
