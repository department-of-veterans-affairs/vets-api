# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/schema_contract/runner'

describe SchemaContract::Runner do
  describe '.run' do
    let(:user) { create(:user) }
    let(:response) do
      OpenStruct.new({ success?: true, status: 200, body: { foo: 'bar' } })
    end

    before do
      Timecop.freeze
      Flipper.enable(:schema_contract_test_index)
    end

    context 'when a record already exists for the current day' do
      before do
        SchemaContractTest.create(name: 'test_index', user_uuid: '1234', response:, status: 'initiated')
      end

      it 'does not create a record or enqueue a job' do
        expect(UpstreamSchemaValidationJob).not_to receive(:perform_async)

        expect do
          SchemaContract::Runner.run(user:, response:, test_name: 'test_index')
        end.not_to change(SchemaContractTest, :count)
      end
    end

    context 'when no record exists for the current day' do
      before do
        SchemaContractTest.create(name: 'test_index', user_uuid: '1234', response:, status: 'initiated',
                                  created_at: Time.zone.yesterday.beginning_of_day)
      end

      it 'creates one with provided details and enqueues a job' do
        expect(UpstreamSchemaValidationJob).to receive(:perform_async)

        expect do
          SchemaContract::Runner.run(user:, response:, test_name: 'test_index')
        end.to change(SchemaContractTest, :count).by(1)
      end
    end

    context 'when an error is encountered' do
      it 'logs but does not raise the error' do
        allow(SchemaContractTest).to receive(:create).with(any_args).and_raise(ArgumentError)
        error_message = { user:, response:, test_name: 'test_index', error_details: "ArgumentError"}
        expect(Rails.logger).to receive(:error).with('Error creating schema contract job', error_message)
        SchemaContract::Runner.run(user:, response:, test_name: 'test_index')
      end
    end
  end
end
