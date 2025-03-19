# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::PaymentHistory', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(email: nil) }

  let(:bgs_payments) do
    {
      payment: [
        {
          beneficiary_participant_id: '600061742',
          file_number: '796043735',
          payee_type: 'Veteran',
          payment_amount: '113.99',
          payment_date: DateTime.parse('Mon, 02 Dec 2019 00:00:00 -0600'),
          payment_status: 'Scheduled',
          payment_type: 'Compensation & Pension - Retroactive',
          payment_type_code: '3',
          program_type: 'Compensation',
          recipient_name: 'WESLEYFORD',
          recipient_participant_id: '600061742',
          scheduled_date: DateTime.parse('Tue, 26 Nov 2019 00:00:00 -0600'),
          veteran_name: 'WESLEYFORD',
          veteran_participant_id: '600061742',
          address_eft: {},
          check_address: {},
          payment_record_identifier: { payment_id: '11122622' },
          return_payment: { check_trace_number: nil, return_reason: nil }
        },
        {
          beneficiary_participant_id: '600061742',
          file_number: '796043735',
          payee_type: 'Veteran',
          payment_amount: '3330.71',
          payment_date: DateTime.parse('Fri, 29 Nov 2019 00:00:00 -0600'),
          payment_status: 'Scheduled',
          payment_type: 'Compensation & Pension - Recurring',
          payment_type_code: '1',
          program_type: 'Compensation',
          recipient_name: 'WESLEYFORD',
          recipient_participant_id: '600061742',
          scheduled_date: DateTime.parse('Tue, 12 Nov 2019 00:00:00 -0600'),
          veteran_name: 'WESLEYFORD',
          veteran_participant_id: '600061742',
          address_eft: {},
          check_address: {},
          payment_record_identifier: { payment_id: '11012780' },
          return_payment: { check_trace_number: nil, return_reason: nil }
        },
        {
          beneficiary_participant_id: '600061742',
          file_number: '796043735',
          payee_type: 'Veteran',
          payment_amount: '3330.71',
          payment_date: DateTime.parse('Wed, 06 Nov 2019 00:00:00 -0600'),
          payment_status: 'Scheduled',
          payment_type: 'Compensation & Pension - Retroactive',
          payment_type_code: '3',
          program_type: 'Compensation',
          recipient_name: 'WESLEYFORD',
          recipient_participant_id: '600061742',
          scheduled_date: DateTime.parse('Fri, 01 Nov 2019 00:00:00 -0500'),
          veteran_name: 'WESLEYFORD',
          veteran_participant_id: '600061742',
          address_eft: {},
          check_address: {},
          payment_record_identifier: { payment_id: '10952622' },
          return_payment: { check_trace_number: nil, return_reason: nil }
        },
        {
          beneficiary_participant_id: '600061742',
          file_number: '796043735',
          payee_type: 'Veteran',
          payment_amount: '3057.13',
          payment_date: DateTime.parse('Mon, 01 Jul 2019 00:00:00 -0500'),
          payment_status: 'Scheduled',
          payment_type: 'Compensation & Pension - Recurring',
          payment_type_code: '1',
          program_type: 'Compensation',
          recipient_name: 'WESLEYFORD',
          recipient_participant_id: '600061742',
          scheduled_date: DateTime.parse('Wed, 19 Jun 2019 00:00:00 -0500'),
          veteran_name: 'WESLEYFORD',
          veteran_participant_id: '600061742',
          address_eft: {},
          check_address: {},
          payment_record_identifier: { payment_id: '10142672' },
          return_payment: { check_trace_number: nil, return_reason: nil }
        }
      ]
    }
  end

  describe 'GET /mobile/v0/payment-history' do
    context 'without bgs access' do
      let!(:user) { sis_user(participant_id: nil) }

      it 'returns 403' do
        get '/mobile/v0/payment-history', headers: sis_headers, params: nil

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with successful response with the default (no) parameters' do
      before do
        VCR.use_cassette('mobile/payment_history/retrieve_payment_summary_with_bdn',
                         match_requests_on: %i[method uri]) do
          get '/mobile/v0/payment-history', headers: sis_headers, params: nil
        end
      end

      it 'returns 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches expected schema' do
        expect(response.body).to match_json_schema('payment_history')
      end

      it 'includes the expected properties for payment history' do
        expect(response.parsed_body['data'].first).to include(
          {
            'id' => '11213114',
            'type' => 'payment_history',
            'attributes' => {
              'amount' => '$3,444.70',
              'date' => '2019-12-31T00:00:00.000-06:00',
              'paymentMethod' => 'Direct Deposit',
              'paymentType' => 'Compensation & Pension - Recurring',
              'bank' => 'BANK OF AMERICA, N.A.',
              'account' => '**3456'
            }
          }
        )
      end

      it 'returns meta data that includes the years in which the user has payments' do
        expect(response.parsed_body['meta']).to include(
          {
            'availableYears' => [2019, 2018, 2017, 2016, 2015]
          }
        )
      end

      it 'only paginates and returns the number of records for the latest year' do
        expect(response.parsed_body['meta']).to include(
          {
            'pagination' => {
              'currentPage' => 1,
              'perPage' => 10,
              'totalPages' => 1,
              'totalEntries' => 7
            }
          }
        )
      end

      it 'returns meta data that includes the recurring payment' do
        expect(response.parsed_body['meta']).to include(
          {
            'recurringPayment' => {
              'amount' => '$3,444.70',
              'date' => '2019-12-31T00:00:00.000-06:00'
            }
          }
        )
      end
    end

    context 'with successful response and recurring payment is not the first payment' do
      before do
        allow_any_instance_of(BGS::PaymentService)
          .to receive(:payment_history).and_return({ payments: bgs_payments })
        get '/mobile/v0/payment-history', headers: sis_headers
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the first payment with "Compensation & Pension - Recurring" paymentType' do
        expect(response.parsed_body['meta']).to include(
          {
            'recurringPayment' => {
              'amount' => '$3,330.71',
              'date' => '2019-11-29T00:00:00.000-06:00'
            }
          }
        )
      end
    end

    context 'with a missing address_eft or account_number' do
      let(:params) do
        {
          startDate: DateTime.new(2015).beginning_of_year.utc.iso8601,
          endDate: DateTime.new(2015).end_of_year.utc.iso8601
        }
      end

      before do
        VCR.use_cassette('mobile/payment_history/retrieve_payment_summary_with_bdn',
                         match_requests_on: %i[method uri]) do
          get '/mobile/v0/payment-history', headers: sis_headers, params:
        end
      end

      it 'returns nil when address_eft or account_number is blank' do
        attributes = response.parsed_body.dig('data', 9, 'attributes')
        expect(attributes['account']).to be_nil
      end
    end

    context 'when address_eft and account_number has value' do
      let(:page) { { number: 1, size: 10 } }
      let(:params) { { page: } }

      before do
        VCR.use_cassette('mobile/payment_history/retrieve_payment_summary_with_bdn',
                         match_requests_on: %i[method uri]) do
          get '/mobile/v0/payment-history', headers: sis_headers, params:
        end
      end

      it 'returns account value when address_eft and account_number have value' do
        attributes = response.parsed_body.dig('data', 0, 'attributes')
        expect(attributes['account']).not_to be_nil
      end
    end

    context 'with invalid pagination params' do
      let(:params) { { page: { number: 'one', size: 'ten' } } }

      before do
        VCR.use_cassette('mobile/payment_history/retrieve_payment_summary_with_bdn',
                         match_requests_on: %i[method uri]) do
          get '/mobile/v0/payment-history', headers: sis_headers, params:
        end
      end

      it 'returns a 422' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'lists the invalid params' do
        expect(response.parsed_body).to eq(
          {
            'errors' =>
              [
                {
                  'title' => 'Validation Error',
                  'detail' => 'page_number must be an integer',
                  'code' => 'MOBL_422_validation_error', 'status' => '422'
                },
                {
                  'title' => 'Validation Error',
                  'detail' => 'page_size must be an integer',
                  'code' => 'MOBL_422_validation_error', 'status' => '422'
                }
              ]
          }
        )
      end
    end

    context 'with a valid date params' do
      let(:params) do
        {
          startDate: DateTime.new(2016).beginning_of_year.utc.iso8601,
          endDate: DateTime.new(2016).end_of_year.utc.iso8601
        }
      end

      before do
        VCR.use_cassette('mobile/payment_history/retrieve_payment_summary_with_bdn',
                         match_requests_on: %i[method uri]) do
          get '/mobile/v0/payment-history', headers: sis_headers, params:
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches expected schema' do
        expect(response.body).to match_json_schema('payment_history')
      end

      it 'only paginates and returns payments for that year' do
        expect(response.parsed_body['meta']).to include(
          {
            'pagination' => {
              'currentPage' => 1,
              'perPage' => 10,
              'totalPages' => 2,
              'totalEntries' => 12
            }
          }
        )
      end
    end

    context 'with a date range that does not include payments' do
      let(:params) do
        {
          startDate: DateTime.new(1776).beginning_of_year.utc.iso8601,
          endDate: DateTime.new(1776).end_of_year.utc.iso8601
        }
      end

      before do
        VCR.use_cassette('mobile/payment_history/retrieve_payment_summary_with_bdn',
                         match_requests_on: %i[method uri]) do
          get '/mobile/v0/payment-history', headers: sis_headers, params:
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches expected schema' do
        expect(response.body).to match_json_schema('payment_history')
      end

      it 'returns an empty list' do
        expect(response.parsed_body['data'].size).to eq(0)
      end

      it 'only paginates and returns payments for that year' do
        expect(response.parsed_body['meta']).to include(
          {
            'pagination' => {
              'currentPage' => 1,
              'perPage' => 10,
              'totalPages' => 0,
              'totalEntries' => 0
            }
          }
        )
      end

      it 'returns most recent recurring payment, even if out of date range' do
        expect(response.parsed_body['meta']).to include(
          {
            'recurringPayment' => {
              'amount' => '$3,444.70',
              'date' => '2019-12-31T00:00:00.000-06:00'
            }
          }
        )
      end
    end

    context 'when payments are an empty list' do
      before do
        allow_any_instance_of(BGS::PaymentService)
          .to receive(:payment_history).and_return({ payments: { payment: [] } })
        get '/mobile/v0/payment-history', headers: sis_headers
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches expected schema' do
        expect(response.body).to match_json_schema('payment_history')
      end

      it 'returns an empty list' do
        expect(response.parsed_body['data'].size).to eq(0)
      end

      it 'returns an empty recurring payment' do
        expect(response.parsed_body['meta']).to include(
          {
            'recurringPayment' => {}
          }
        )
      end
    end

    context 'when payments return as nil' do
      before do
        allow_any_instance_of(BGS::PaymentService)
          .to receive(:payment_history).and_return(nil)
        get '/mobile/v0/payment-history', headers: sis_headers
      end

      it 'returns a 502' do
        expect(response).to have_http_status(:bad_gateway)
      end

      it 'lists the invalid params' do
        expect(response.parsed_body).to eq(
          {
            'errors' =>
              [
                {
                  'title' => 'Bad Gateway',
                  'detail' => 'Received an an invalid response from the upstream server',
                  'code' => 'MOBL_502_upstream_error', 'status' => '502'
                }
              ]
          }
        )
      end
    end

    context 'with an invalid date in payment history' do
      before do
        allow(Rails.logger).to receive(:warn)
        VCR.use_cassette('mobile/payment_history/retrieve_payment_summary_with_bdn_blank_date',
                         match_requests_on: %i[method uri]) do
          get '/mobile/v0/payment-history', headers: sis_headers
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with an only scheduled payments' do
      before do
        allow(Rails.logger).to receive(:warn)
        VCR.use_cassette('mobile/payment_history/retrieve_payment_summary_with_bdn_only_blank_dates',
                         match_requests_on: %i[method uri]) do
          get '/mobile/v0/payment-history', headers: sis_headers
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns no payments' do
        expect(response.parsed_body['data'].size).to eq(0)
      end
    end
  end
end
