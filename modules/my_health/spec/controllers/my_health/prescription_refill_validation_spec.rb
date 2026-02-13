# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyHealth::PrescriptionRefillValidation, type: :controller do
  controller(ApplicationController) do
    include MyHealth::PrescriptionRefillValidation

    def refill
      orders = params[:orders] || []
      validate_refill_orders!(orders, prescriptions_list)
      render json: { success: true }
    end

    def refill_with_service
      orders = params[:orders] || []
      validate_refill_orders!(orders, prescription_service)
      render json: { success: true }
    end

    private

    def prescriptions_list
      @prescriptions_list ||= []
    end

    def prescription_service
      @prescription_service ||= double('Service')
    end
  end

  let(:user) { build(:user, :loa3) }

  # Mock prescription objects with the expected interface
  let(:valid_prescription) do
    OpenStruct.new(
      prescription_id: '12345',
      station_number: '668'
    )
  end

  let(:another_valid_prescription) do
    OpenStruct.new(
      prescription_id: '67890',
      station_number: '570'
    )
  end

  let(:prescription_with_nil_id) do
    OpenStruct.new(
      prescription_id: nil,
      station_number: '668'
    )
  end

  let(:prescription_with_blank_station) do
    OpenStruct.new(
      prescription_id: '11111',
      station_number: ''
    )
  end

  before do
    sign_in_as(user)
    routes.draw do
      post 'refill' => 'anonymous#refill'
      post 'refill_with_service' => 'anonymous#refill_with_service'
    end
  end

  describe '#validate_refill_orders!' do
    context 'when passed a pre-loaded prescription list' do
      context 'when all orders match valid prescriptions' do
        before do
          allow(controller).to receive(:prescriptions_list).and_return([
                                                                         valid_prescription,
                                                                         another_valid_prescription
                                                                       ])
        end

        it 'passes validation for a single matching order' do
          post :refill, params: { orders: [{ 'id' => '12345', 'stationNumber' => '668' }] }

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq('success' => true)
        end

        it 'passes validation for multiple matching orders' do
          post :refill, params: {
            orders: [
              { 'id' => '12345', 'stationNumber' => '668' },
              { 'id' => '67890', 'stationNumber' => '570' }
            ]
          }

          expect(response).to have_http_status(:ok)
        end

        it 'handles string/integer type coercion for prescription_id' do
          # Prescription has integer ID, order has string ID
          prescription_with_int_id = OpenStruct.new(prescription_id: 12_345, station_number: '668')
          allow(controller).to receive(:prescriptions_list).and_return([prescription_with_int_id])

          post :refill, params: { orders: [{ 'id' => '12345', 'stationNumber' => '668' }] }

          expect(response).to have_http_status(:ok)
        end

        it 'handles string/integer type coercion for station_number' do
          # Prescription has integer station, order has string station
          prescription_with_int_station = OpenStruct.new(prescription_id: '12345', station_number: 668)
          allow(controller).to receive(:prescriptions_list).and_return([prescription_with_int_station])

          post :refill, params: { orders: [{ 'id' => '12345', 'stationNumber' => '668' }] }

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when order does not match any prescription' do
        before do
          allow(controller).to receive(:prescriptions_list).and_return([valid_prescription])
          allow(Rails.logger).to receive(:warn)
        end

        it 'raises InvalidFieldValue for non-existent prescription ID' do
          post :refill, params: { orders: [{ 'id' => '99999', 'stationNumber' => '668' }] }

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body['errors'].first['detail']).to include('orders[0]')
        end

        it 'raises InvalidFieldValue for mismatched station number' do
          post :refill, params: { orders: [{ 'id' => '12345', 'stationNumber' => '999' }] }

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body['errors'].first['detail']).to include('orders[0]')
        end

        it 'logs the validation failure with details' do
          post :refill, params: { orders: [{ 'id' => '99999', 'stationNumber' => '668' }] }

          expect(Rails.logger).to have_received(:warn).with(
            hash_including(
              message: 'Refill validation failed',
              order_index: 0,
              prescription_id: '99999',
              station_number: '668',
              service: 'prescription_refill_validation'
            )
          )
        end

        it 'includes the correct order index in error message' do
          allow(controller).to receive(:prescriptions_list).and_return([
                                                                         valid_prescription,
                                                                         another_valid_prescription
                                                                       ])

          # First order valid, second order invalid
          post :refill, params: {
            orders: [
              { 'id' => '12345', 'stationNumber' => '668' },
              { 'id' => '99999', 'stationNumber' => '999' }
            ]
          }

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body['errors'].first['detail']).to include('orders[1]')
        end
      end

      context 'when prescription has blank identifiers' do
        before do
          allow(Rails.logger).to receive(:warn)
        end

        it 'does not match prescription with nil prescription_id' do
          allow(controller).to receive(:prescriptions_list).and_return([prescription_with_nil_id])

          post :refill, params: { orders: [{ 'id' => '', 'stationNumber' => '668' }] }

          expect(response).to have_http_status(:bad_request)
        end

        it 'does not match prescription with blank station_number' do
          allow(controller).to receive(:prescriptions_list).and_return([prescription_with_blank_station])

          post :refill, params: { orders: [{ 'id' => '11111', 'stationNumber' => '' }] }

          expect(response).to have_http_status(:bad_request)
        end
      end

      context 'when prescription list contains nil values' do
        before do
          allow(controller).to receive(:prescriptions_list).and_return([
                                                                         nil,
                                                                         valid_prescription,
                                                                         nil
                                                                       ])
        end

        it 'compacts nil values and validates successfully' do
          post :refill, params: { orders: [{ 'id' => '12345', 'stationNumber' => '668' }] }

          expect(response).to have_http_status(:ok)
        end
      end

      context 'with empty orders array' do
        before do
          allow(controller).to receive(:prescriptions_list).and_return([valid_prescription])
        end

        it 'passes validation when no orders to validate' do
          post :refill, params: { orders: [] }

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when passed a service object' do
      let(:mock_service) { double('UnifiedHealthData::Service') }

      before do
        allow(controller).to receive(:prescription_service).and_return(mock_service)
      end

      it 'calls get_prescriptions on the service with current_only: false' do
        expect(mock_service).to receive(:get_prescriptions)
          .with(current_only: false)
          .and_return([valid_prescription])

        post :refill_with_service, params: { orders: [{ 'id' => '12345', 'stationNumber' => '668' }] }

        expect(response).to have_http_status(:ok)
      end

      it 'validates against prescriptions returned by service' do
        allow(mock_service).to receive(:get_prescriptions)
          .with(current_only: false)
          .and_return([valid_prescription])
        allow(Rails.logger).to receive(:warn)

        post :refill_with_service, params: { orders: [{ 'id' => '99999', 'stationNumber' => '668' }] }

        expect(response).to have_http_status(:bad_request)
      end

      it 'compacts nil values from service response' do
        allow(mock_service).to receive(:get_prescriptions)
          .with(current_only: false)
          .and_return([nil, valid_prescription, nil])

        post :refill_with_service, params: { orders: [{ 'id' => '12345', 'stationNumber' => '668' }] }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe '#find_matching_prescription' do
    # This is a private method, but we can test its behavior through validate_refill_orders!

    context 'matching logic' do
      before do
        allow(controller).to receive(:prescriptions_list).and_return([
                                                                       valid_prescription,
                                                                       another_valid_prescription
                                                                     ])
      end

      it 'requires exact match on both prescription_id and station_number' do
        # Valid prescription has id: '12345', station: '668'
        # Order with wrong station should fail
        allow(Rails.logger).to receive(:warn)

        post :refill, params: { orders: [{ 'id' => '12345', 'stationNumber' => '570' }] }

        expect(response).to have_http_status(:bad_request)
      end

      it 'matches when both values are equal after to_s conversion' do
        prescription_with_mixed_types = OpenStruct.new(prescription_id: 12_345, station_number: 668)
        allow(controller).to receive(:prescriptions_list).and_return([prescription_with_mixed_types])

        post :refill, params: { orders: [{ 'id' => '12345', 'stationNumber' => '668' }] }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
