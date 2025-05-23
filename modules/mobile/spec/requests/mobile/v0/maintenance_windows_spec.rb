# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::MaintenanceWindows', type: :request do
  include JsonSchemaMatchers

  def mw_uuid(service_name)
    Digest::UUID.uuid_v5(Mobile::V0::ServiceGraph::MAINTENANCE_WINDOW_NAMESPACE, service_name)
  end

  describe 'GET /v0/maintenance_windows' do
    context 'when no maintenance windows are active' do
      before { get '/mobile/v0/maintenance_windows', headers: { 'X-Key-Inflection' => 'camel' } }

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('maintenance_windows')
      end

      it 'returns an empty array of affected services' do
        expect(response.parsed_body['data']).to eq([])
      end
    end

    context 'when no maintenance windows that have not already ended are active' do
      before do
        Timecop.freeze('2021-05-26 22:33:39')

        create(:mobile_maintenance_evss_first)
        get '/mobile/v0/maintenance_windows', headers: { 'X-Key-Inflection' => 'camel' }
      end

      after { Timecop.return }

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('maintenance_windows')
      end

      it 'returns an empty array of affected services' do
        expect(response.parsed_body['data']).to eq([])
      end
    end

    context 'when a maintenance with many dependent services and a window not in the service map is active' do
      before do
        Timecop.freeze('2021-05-25T03:33:39Z')
        create(:mobile_maintenance_evss_first)
        create(:mobile_maintenance_mpi)
        create(:mobile_maintenance_dslogon)
        create(:mobile_maintenance_vbms)
        get '/mobile/v0/maintenance_windows', headers: { 'X-Key-Inflection' => 'camel' }
      end

      after { Timecop.return }

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('maintenance_windows')
      end

      it 'returns an array of the affected services' do
        expect(response.parsed_body['data']).to eq(
          {
            'id' => mw_uuid('disability_rating'),
            'type' => 'maintenance_window',
            'attributes' => {
              'service' => 'disability_rating',
              'startTime' => '2021-05-25T23:33:39.000Z',
              'endTime' => '2021-05-26T01:45:00.000Z'
            }
          }, {
            'id' => mw_uuid('letters_and_documents'),
            'type' => 'maintenance_window',
            'attributes' => {
              'service' => 'letters_and_documents',
              'startTime' => '2021-05-25T21:33:39.000Z',
              'endTime' => '2021-05-25T22:33:39.000Z'
            }
          }, {
            'id' => 'ebd9fb30-4df2-52e9-b951-297a9a4cc65c',
            'type' => 'maintenance_window',
            'attributes' => {
              'service' => 'claims',
              'startTime' => '2021-05-25T23:33:39.000Z',
              'endTime' => '2021-05-26T01:45:00.000Z'
            }
          }, {
            'id' => '0ce167f8-9522-52c3-94e0-4f1e367d7064',
            'type' => 'maintenance_window',
            'attributes' => {
              'service' => 'immunizations',
              'startTime' => '2021-05-25T23:33:39.000Z',
              'endTime' => '2021-05-26T01:45:00.000Z'
            }
          }, {
            'id' => 'c07d7af4-b54a-5b82-b94c-3366f79cc500',
            'type' => 'maintenance_window',
            'attributes' => {
              'service' => 'efolder',
              'startTime' => '2021-05-25T23:33:39.000Z',
              'endTime' => '2021-05-27T01:45:00.000Z'
            }
          }
        )
      end
    end

    context 'when BGS is down' do
      before do
        Timecop.freeze('2021-05-25T03:33:39Z')
        create(:mobile_maintenance_bgs_first)
        get '/mobile/v0/maintenance_windows', headers: { 'X-Key-Inflection' => 'camel' }
      end

      after { Timecop.return }

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('maintenance_windows')
      end

      it 'includes payment history as an affected service' do
        expect(response.parsed_body['data']).to include(
          {
            'id' => mw_uuid('payment_history'),
            'type' => 'maintenance_window',
            'attributes' => {
              'service' => 'payment_history',
              'startTime' => '2021-05-25T23:33:39.000Z',
              'endTime' => '2021-05-26T01:45:00.000Z'
            }
          }
        )
      end
    end

    context 'when there are multiple windows for same service with different time spans' do
      let!(:earliest_evss_starting) { create(:mobile_maintenance_evss_first) }
      let!(:middle_evss_starting) { create(:mobile_maintenance_evss_second) }
      let!(:latest_evss_starting) { create(:mobile_maintenance_evss_third) }

      before { Timecop.freeze('2021-05-25T03:33:39Z') }
      after { Timecop.return }

      it 'shows closest window to now in the future' do
        get '/mobile/v0/maintenance_windows', headers: { 'X-Key-Inflection' => 'camel' }

        attributes = response.parsed_body['data'].pluck('attributes')
        evss_eariest_start_time = earliest_evss_starting.start_time.iso8601
        evss_eariest_end_time = earliest_evss_starting.end_time.iso8601
        evss_middle_start_time = middle_evss_starting.start_time.iso8601
        evss_middle_end_time = middle_evss_starting.end_time.iso8601
        evss_latest_start_time = latest_evss_starting.start_time.iso8601
        evss_latest_end_time = latest_evss_starting.end_time.iso8601

        expect(response.body).to match_json_schema('maintenance_windows')
        expect(attributes.pluck('service').uniq).to eq(%w[letters_and_documents])
        expect(attributes.map { |w| Time.parse(w['startTime']).iso8601 }.uniq).to eq([evss_eariest_start_time])
        expect(attributes.map { |w| Time.parse(w['endTime']).iso8601 }.uniq).to eq([evss_eariest_end_time])

        Timecop.freeze('2021-05-26T03:33:39Z')
        get '/mobile/v0/maintenance_windows', headers: { 'X-Key-Inflection' => 'camel' }

        expect(response.body).to match_json_schema('maintenance_windows')
        attributes = response.parsed_body['data'].pluck('attributes')
        expect(attributes.pluck('service').uniq).to eq(%w[letters_and_documents])
        expect(attributes.map { |w| Time.parse(w['startTime']).iso8601 }.uniq).to eq([evss_middle_start_time])
        expect(attributes.map { |w| Time.parse(w['endTime']).iso8601 }.uniq).to eq([evss_middle_end_time])

        Timecop.freeze('2021-05-27T03:33:39Z')
        get '/mobile/v0/maintenance_windows', headers: { 'X-Key-Inflection' => 'camel' }

        expect(response.body).to match_json_schema('maintenance_windows')
        attributes = response.parsed_body['data'].pluck('attributes')
        expect(attributes.pluck('service').uniq).to eq(%w[letters_and_documents])

        expect(attributes.map { |w| Time.parse(w['startTime']).iso8601 }.uniq).to eq([evss_latest_start_time])
        expect(attributes.map { |w| Time.parse(w['endTime']).iso8601 }.uniq).to eq([evss_latest_end_time])
      end
    end

    context 'when there are multiple windows for various services with different time spans' do
      let!(:earliest_evss_starting) { create(:mobile_maintenance_evss_first) }
      let!(:latest_evss_starting) { create(:mobile_maintenance_evss_second) }
      let!(:earliest_bgs_starting) { create(:mobile_maintenance_bgs_first) }
      let!(:latest_bgs_starting) { create(:mobile_maintenance_bgs_second) }
      let(:evss_services) { %w[letters_and_documents].freeze }
      let(:bgs_services) { %w[payment_history appeals].freeze }

      before { Timecop.freeze('2021-05-25T03:33:39Z') }
      after { Timecop.return }

      it 'shows closest window to now in the future' do
        get '/mobile/v0/maintenance_windows', headers: { 'X-Key-Inflection' => 'camel' }

        attributes = response.parsed_body['data'].pluck('attributes')
        evss_windows = attributes.select { |window| evss_services.include?(window['service']) }
        bgs_windows = attributes.select { |window| bgs_services.include?(window['service']) }
        evss_eariest_start_time = earliest_evss_starting.start_time.iso8601
        evss_eariest_end_time = earliest_evss_starting.end_time.iso8601
        bgs_eariest_start_time = earliest_bgs_starting.start_time.iso8601
        bgs_eariest_end_time = earliest_bgs_starting.end_time.iso8601

        expect(response.body).to match_json_schema('maintenance_windows')
        expect(evss_windows.pluck('service')).to eq(evss_services)
        expect(evss_windows.map { |w| Time.parse(w['startTime']).iso8601 }.uniq).to eq([evss_eariest_start_time])
        expect(evss_windows.map { |w| Time.parse(w['endTime']).iso8601 }.uniq).to eq([evss_eariest_end_time])
        expect(bgs_windows.pluck('service')).to eq(bgs_services)
        expect(bgs_windows.map { |w| Time.parse(w['startTime']).iso8601 }.uniq).to eq([bgs_eariest_start_time])
        expect(bgs_windows.map { |w| Time.parse(w['endTime']).iso8601 }.uniq).to eq([bgs_eariest_end_time])

        Timecop.freeze('2021-05-26 03:45:00')
        get '/mobile/v0/maintenance_windows', headers: { 'X-Key-Inflection' => 'camel' }

        attributes = response.parsed_body['data'].pluck('attributes')
        evss_windows = attributes.select { |window| evss_services.include?(window['service']) }
        bgs_windows = attributes.select { |window| bgs_services.include?(window['service']) }
        evss_latest_start_time = latest_evss_starting.start_time.iso8601
        evss_latest_end_time = latest_evss_starting.end_time.iso8601
        bgs_latest_start_time = latest_bgs_starting.start_time.iso8601
        bgs_latest_end_time = latest_bgs_starting.end_time.iso8601

        expect(response.body).to match_json_schema('maintenance_windows')
        expect(evss_windows.pluck('service')).to eq(evss_services)
        expect(evss_windows.map { |w| Time.parse(w['startTime']).iso8601 }.uniq).to eq([evss_latest_start_time])
        expect(evss_windows.map { |w| Time.parse(w['endTime']).iso8601 }.uniq).to eq([evss_latest_end_time])
        expect(bgs_windows.pluck('service')).to eq(bgs_services)
        expect(bgs_windows.map { |w| Time.parse(w['startTime']).iso8601 }.uniq).to eq([bgs_latest_start_time])
        expect(bgs_windows.map { |w| Time.parse(w['endTime']).iso8601 }.uniq).to eq([bgs_latest_end_time])
      end
    end
  end
end
