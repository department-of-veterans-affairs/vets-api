# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

describe TravelPay::SmocService do
  context 'submit_mileage_only_claim' do
    let(:user) { build(:user) }

    let(:appointment_data) do
      {
        'id' => '73611905-71bf-46ed-b1ec-e790593b8565',
        'appointmentSource' => 'API',
        'appointmentDateTime' => '2024-01-01T16:45:34.465Z',
        'appointmentName' => 'string',
        'appointmentType' => 'EnvironmentalHealth',
        'facilityName' => 'Cheyenne VA Medical Center',
        'serviceConnectedDisability' => 30,
        'currentStatus' => 'string',
        'appointmentStatus' => 'Completed',
        'externalAppointmentId' => '12345678-0000-0000-0000-000000000001',
        'associatedClaimId' => nil,
        'associatedClaimNumber' => nil,
        'isCompleted' => true
      }
    end

    let(:new_claim_data) do
      {
        'claimId' => '3fa85f64-5717-4562-b3fc-2c963f66afa6'
      }
    end

    let(:add_expense_data) do
      {
        'expenseId' => '3fa85f64-5717-4562-b3fc-2c963f66afa6'
      }
    end

    let(:submit_claim_data) do
      {
        'claimId' => '3fa85f64-5717-4562-b3fc-2c963f66afa6'
      }
    end

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

    before do
      auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
      @smoc_service = TravelPay::SmocService.new(auth_manager, user)

      @params = { 'appointment_date_time' => '2024-01-01T16:45:34',
                  'facility_station_number' => '123',
                  'appointment_type' => 'Other',
                  'is_complete' => false }

      allow_any_instance_of(TravelPay::AppointmentsService)
        .to receive(:find_or_create_appointment)
        .with(@params)
        .and_return(appointment_data)
      allow_any_instance_of(TravelPay::ClaimsService)
        .to receive(:create_new_claim)
        .and_return(new_claim_data)
      allow_any_instance_of(TravelPay::ExpensesService)
        .to receive(:add_expense)
        .with({ 'claim_id' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                'appt_date' => '2024-01-01T16:45:34' })
        .and_return(add_expense_data)
      allow_any_instance_of(TravelPay::ClaimsService)
        .to receive(:submit_claim)
        .and_return(submit_claim_data)
    end

    it 'returns a claim ID and claim submitted status when submit is successful' do
      actual_claim_response = @smoc_service.submit_mileage_expense(@params)
      expect(actual_claim_response).to eq({ 'claimId' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                                            'status' => 'Claim submitted' })
    end

    it 'returns a claim ID and incomplete status when add expense fails' do
      allow_any_instance_of(TravelPay::ExpensesService)
        .to receive(:add_expense)
        .with({ 'claim_id' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                'appt_date' => '2024-01-01T16:45:34' })
        .and_raise(StandardError, message: 'Internal server error')

      actual_claim_response = @smoc_service.submit_mileage_expense(@params)
      expect(actual_claim_response).to eq({ 'claimId' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                                            'status' => 'Incomplete' })
    end

    it 'returns a claim ID and saved status when add expense fails' do
      allow_any_instance_of(TravelPay::ClaimsService)
        .to receive(:submit_claim)
        .and_raise(StandardError, message: 'Internal server error')

      actual_claim_response = @smoc_service.submit_mileage_expense(@params)
      expect(actual_claim_response).to eq({ 'claimId' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                                            'status' => 'Saved' })
    end

    # TODO: fix this
    #
    # it 'raises an exception if it fails to create the claim' do
    #   allow_any_instance_of(TravelPay::ClaimsService)
    #     .to receive(:create_new_claim)
    #     .and_return(nil)

    #   expect do
    #     @smoc_service.submit_mileage_expense(@params)
    #   end.to raise_error(Common::Exceptions::InternalServerError,
    #                      /Internal server error/)
    # end

    it 'raises an exception if it fails to find or create the appointment' do
      allow_any_instance_of(TravelPay::AppointmentsService)
        .to receive(:find_or_create_appointment)
        .with(@params)
        .and_raise(ArgumentError, message: 'Invalid appointment time')

      expect do
        @smoc_service.submit_mileage_expense(@params)
      end.to raise_error(Common::Exceptions::BadRequest, 'Bad request')
    end
  end
end
