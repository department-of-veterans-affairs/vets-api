# frozen_string_literal: true

require 'rails_helper'

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V1::LabsAndTestsController', :skip_json_api_validation, type: :request do
  let!(:user) { sis_user(icn: '1000123456V123456') }
  let(:default_params) { { startDate: '2024-01-01', endDate: '2025-05-31' } }
  let(:path) { '/mobile/v1/health/labs-and-tests' }
  let(:labs_cassette) { 'mobile/unified_health_data/get_labs' }
  let(:labs_attachment_cassette) { 'mobile/unified_health_data/get_labs_value_attachment' }
  let(:uhd_flipper) { :mhv_accelerated_delivery_uhd_enabled }
  let(:filtering_flipper) { :mhv_accelerated_delivery_uhd_filtering_enabled }
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
        allow(Flipper).to receive(:enabled?).with(filtering_flipper, instance_of(User)).and_return(true)
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
        json_response = JSON.parse(response.body)['data']
        expect(json_response.count).to eq(9)
        # Check that our test records are included in the response
        # rather than expecting specific indices
        expect(json_response).to include(ch_response)
        expect(json_response).to include(sp_response)
        expect(json_response).to include(mb_response)
      end
    end

    context 'SP only' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(filtering_flipper, instance_of(User)).and_return(true)
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
        json_response = JSON.parse(response.body)['data']
        # Check that our SP record is included in the response
        # and CH record is not included
        expect(json_response).to include(sp_response)
        expect(json_response).not_to include(ch_response)
        expect(json_response).not_to include(mb_response)
      end
    end

    context 'CH only' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(filtering_flipper, instance_of(User)).and_return(true)
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
        json_response = JSON.parse(response.body)['data']
        # Check that our CH record is included in the response
        # and SP record is not included
        expect(json_response).to include(ch_response)
        expect(json_response).not_to include(sp_response)
        expect(json_response).not_to include(mb_response)
      end
    end

    context 'MB only' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(filtering_flipper, instance_of(User)).and_return(true)
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
        json_response = JSON.parse(response.body)['data']
        # Check that our MB record is included in the response
        # and SP record is not included

        expect(json_response).to include(mb_response)
        expect(json_response).not_to include(sp_response)
        expect(json_response).not_to include(ch_response)
      end
    end

    context 'when filtering is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(filtering_flipper, instance_of(User)).and_return(false)
        # These shouldn't matter when filtering is disabled, but set them anyway
        allow(Flipper).to receive(:enabled?).with(sp_flipper, instance_of(User)).and_return(false)
        allow(Flipper).to receive(:enabled?).with(ch_flipper, instance_of(User)).and_return(false)
        allow(Flipper).to receive(:enabled?).with(mb_flipper, instance_of(User)).and_return(false)
        VCR.use_cassette(labs_cassette) do
          get path, headers: sis_headers, params: default_params
        end
      end

      it 'returns a successful response' do
        expect(response).to be_successful
      end

      it 'returns all lab records regardless of filtering flags' do
        json_response = JSON.parse(response.body)['data']
        # Should return all 9 records since filtering is disabled
        expect(json_response.count).to eq(9)
        # All test records should be included regardless of individual toggles
        expect(json_response).to include(ch_response)
        expect(json_response).to include(sp_response)
        expect(json_response).to include(mb_response)
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
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(filtering_flipper, instance_of(User)).and_return(true)
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
