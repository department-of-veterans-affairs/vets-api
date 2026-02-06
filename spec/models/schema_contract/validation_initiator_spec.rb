# frozen_string_literal: true

require 'rails_helper'
require_relative Rails.root.join('app', 'models', 'schema_contract', 'validation_initiator')

describe SchemaContract::ValidationInitiator do
  describe '.call' do
    let(:user) { create(:user, :with_terms_of_use_agreement) }
    let(:user_account_id) { user.user_account_uuid }
    let(:response) do
      OpenStruct.new({ success?: true, status: 200, body: { key: 'value' } })
    end

    before do
      Timecop.freeze
      Flipper.enable(:schema_contract_test_index) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    end

    context 'response is successful, feature flag is on, and no record exists for the current day' do
      before do
        create(:schema_contract_validation, contract_name: 'test_index', user_account_id:, user_uuid: '1234', response:,
                                            status: 'initialized', created_at: Time.zone.yesterday.beginning_of_day)
      end

      it 'creates a record with provided details and enqueues a job' do
        expect(SchemaContract::ValidationJob).to receive(:perform_async)
        expect do
          SchemaContract::ValidationInitiator.call(user:, response:, contract_name: 'test_index')
        end.to change(SchemaContract::Validation, :count).by(1)
      end
    end

    context 'when a validation record already exists for the current day' do
      before do
        create(:schema_contract_validation, contract_name: 'test_index', user_account_id:, user_uuid: '1234', response:,
                                            status: 'initialized')
      end

      it 'does not create a record or enqueue a job' do
        expect(SchemaContract::ValidationJob).not_to receive(:perform_async)
        expect do
          SchemaContract::ValidationInitiator.call(user:, response:, contract_name: 'test_index')
        end.not_to change(SchemaContract::Validation, :count)
      end
    end

    context 'when feature flag is off' do
      before { Flipper.disable(:schema_contract_test_index) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

      it 'does not create a record or enqueue a job' do
        expect(SchemaContract::ValidationJob).not_to receive(:perform_async)
        expect do
          SchemaContract::ValidationInitiator.call(user:, response:, contract_name: 'test_index')
        end.not_to change(SchemaContract::Validation, :count)
      end
    end

    context 'when response is unsuccessful' do
      let(:response) do
        OpenStruct.new({ success?: false, status: 200, body: { key: 'value' } })
      end

      it 'does not create a record or enqueue a job' do
        expect(SchemaContract::ValidationJob).not_to receive(:perform_async)
        expect do
          SchemaContract::ValidationInitiator.call(user:, response:, contract_name: 'test_index')
        end.not_to change(SchemaContract::Validation, :count)
      end
    end

    context 'when an error is encountered' do
      it 'logs but does not raise the error' do
        allow(SchemaContract::Validation).to receive(:create).with(any_args).and_raise(ArgumentError)
        error_message = { response:, contract_name: 'test_index', error_details: 'ArgumentError' }
        expect(Rails.logger).to receive(:error).with('Error creating schema contract job', error_message)
        expect do
          SchemaContract::ValidationInitiator.call(user:, response:, contract_name: 'test_index')
        end.not_to raise_error
      end
    end
  end
end
