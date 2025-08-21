# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::MileageExpenseService do
  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in_session) { CheckIn::V2::Session.build(data: { uuid: }) }
  let(:auth_manager) { instance_double(TravelClaim::AuthManager) }
  let(:client) { instance_double(TravelClaim::MileageExpenseClient) }
  let(:service) { described_class.new(check_in_session:, auth_manager:) }

  let(:claim_id) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:date_incurred) { '2024-01-15T10:00:00Z' }
  let(:correlation_id) { 'correlation-123' }

  before do
    allow(TravelClaim::MileageExpenseClient).to receive(:new).and_return(client)
  end

  describe '#initialize' do
    it 'accepts check_in_session parameter' do
      service = described_class.new(check_in_session:, auth_manager:)
      expect(service.check_in_session).to eq(check_in_session)
    end

    it 'uses provided auth_manager' do
      service = described_class.new(check_in_session:, auth_manager:)
      expect(service.auth_manager).to eq(auth_manager)
    end

    it 'requires both parameters' do
      expect { described_class.new }.to raise_error(ArgumentError)
      expect { described_class.new(check_in_session:) }.to raise_error(ArgumentError)
      expect { described_class.new(auth_manager:) }.to raise_error(ArgumentError)
    end
  end

  describe '#add_mileage_expense' do
    let(:mock_response) do
      double('Response', body: { 'data' => { 'expenseId' => 'expense-uuid-789' } })
    end

    before do
      allow(auth_manager).to receive(:authorize).and_return({
                                                              veis_token: 'veis-token',
                                                              btsss_token: 'btsss-token'
                                                            })
      allow(client).to receive(:add_mileage_expense).and_return(mock_response)
    end

    context 'with valid parameters' do
      it 'successfully adds mileage expense' do
        expect(client).to receive(:add_mileage_expense).with(
          tokens: { veis_token: 'veis-token', btsss_token: 'btsss-token' },
          claim_id:,
          date_incurred:,
          correlation_id:
        ).and_return(mock_response)

        result = service.add_mileage_expense(
          claim_id:,
          date_incurred:,
          correlation_id:
        )

        expect(result[:data]).to eq({ 'expenseId' => 'expense-uuid-789' })
      end
    end

    context 'parameter validation' do
      it 'validates claim_id is not nil' do
        expect do
          service.add_mileage_expense(
            claim_id: nil,
            date_incurred:,
            correlation_id:
          )
        end.to raise_error(ArgumentError, /claim ID cannot be nil/)
      end



      it 'validates date_incurred is not nil' do
        expect do
          service.add_mileage_expense(
            claim_id:,
            date_incurred: nil,
            correlation_id:
          )
        end.to raise_error(ArgumentError, /date incurred cannot be nil/)
      end

      it 'validates date_incurred format is ISO 8601' do
        expect do
          service.add_mileage_expense(
            claim_id:,
            date_incurred: 'invalid-date',
            correlation_id:
          )
        end.to raise_error(ArgumentError, /Expected ISO 8601 format/)
      end

      it 'accepts valid ISO 8601 format date_incurred' do
        expect do
          service.add_mileage_expense(
            claim_id:,
            date_incurred: '2024-06-01T10:00:00Z',
            correlation_id:
          )
        end.not_to raise_error
      end
    end

    context 'when API call fails with claim already exists error' do
      it 'raises BackendServiceException' do
        allow(client).to receive(:add_mileage_expense).and_raise(Common::Exceptions::BackendServiceException,
                                                                 'Claim already exists')
        allow(Rails.logger).to receive(:error)

        expect do
          service.add_mileage_expense(
            claim_id:,
            date_incurred:,
            correlation_id:
          )
        end.to raise_error(Common::Exceptions::BackendServiceException)

        expect(Rails.logger).to have_received(:error).with(
          'Travel Claim Mileage Expense API error',
          {
            uuid:,
            claim_id:,
            error_class: 'Common::Exceptions::BackendServiceException',
            error_message: 'BackendServiceException: {:code=>"VA900"}'
          }
        )
      end
    end

    context 'when API call fails with other validation error' do
      it 'raises BackendServiceException' do
        allow(client).to receive(:add_mileage_expense).and_raise(Common::Exceptions::BackendServiceException,
                                                                 'Invalid description')
        allow(Rails.logger).to receive(:error)

        expect do
          service.add_mileage_expense(
            claim_id:,
            date_incurred:,
            correlation_id:
          )
        end.to raise_error(Common::Exceptions::BackendServiceException)

        expect(Rails.logger).to have_received(:error).with(
          'Travel Claim Mileage Expense API error',
          {
            uuid:,
            claim_id:,
            error_class: 'Common::Exceptions::BackendServiceException',
            error_message: 'BackendServiceException: {:code=>"VA900"}'
          }
        )
      end
    end

    context 'when auth_manager fails' do
      it 'logs error and re-raises exception' do
        allow(auth_manager).to receive(:authorize).and_raise(StandardError, 'Auth Error')
        allow(Rails.logger).to receive(:error)

        expect do
          service.add_mileage_expense(
            claim_id:,
            date_incurred:,
            correlation_id:
          )
        end.to raise_error(StandardError, 'Auth Error')

        expect(Rails.logger).to have_received(:error).with(
          'Travel Claim Mileage Expense API error',
          {
            uuid:,
            claim_id:,
            error_class: 'StandardError',
            error_message: 'Auth Error'
          }
        )
      end
    end
  end

  describe 'inheritance and modules' do
    it 'is a plain class' do
      expect(described_class.superclass).to eq(Object)
    end
  end
end
