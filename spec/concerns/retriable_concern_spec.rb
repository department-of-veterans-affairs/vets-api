# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RetriableConcern do
  let(:dummy_class) { Class.new { include RetriableConcern }.new }
  let(:block_name) { 'Doing a thing' }
  let(:exception_message) { 'Temporary failure' }

  describe '#with_retries' do
    context 'when the block succeeds on the first attempt' do
      it 'returns the result immediately' do
        result = dummy_class.with_retries(block_name) { 'success' }
        expect(result).to eq('success')
      end
    end

    context 'when the block fails and then succeeds' do
      it 'retries the operation and returns the successful result' do
        expect(Rails.logger).to receive(:warn)
          .with("Retrying #{block_name} (Attempt 2/3)")

        expect(Rails.logger).to receive(:info)
          .with("#{block_name} succeeded on attempt 2/3")

        attempts = 0

        result = dummy_class.with_retries(block_name, tries: 3) do
          attempts += 1
          raise exception_message if attempts < 2

          'success'
        end

        expect(result).to eq('success')
        expect(attempts).to eq(2)
      end
    end

    context 'when the block fails all attempts' do
      it 'raises an error after max retries' do
        permanent_failure = 'Permanent failure'
        expect(Rails.logger).to receive(:warn)
          .with("Retrying #{block_name} (Attempt 2/3)")
        expect(Rails.logger).to receive(:warn)
          .with("Retrying #{block_name} (Attempt 3/3)")

        expect(Rails.logger).to receive(:error).with(
          "#{block_name} failed after max retries",
          hash_including(error: permanent_failure, backtrace: kind_of(Array))
        )

        attempts = 0

        expect do
          dummy_class.with_retries(block_name, tries: 3) do
            attempts += 1
            raise permanent_failure
          end
        end.to raise_error(RuntimeError, permanent_failure)

        expect(attempts).to eq(3)
      end
    end
  end
end
