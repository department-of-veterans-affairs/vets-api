# frozen_string_literal: true

require 'rails_helper'

describe IvcChampva::Retry do
  describe '#do' do
    it 'returns the result of the block' do
      result = IvcChampva::Retry.do(1, 0) do
        'test'
      end

      expect(result).to eq('test')
    end

    it 'invokes the on_failure block if the block raises an error' do
      failure = false
      on_failure = proc {
        failure = true
      }

      IvcChampva::Retry.do(1, 0, on_failure:) do
        raise StandardError, 'Standard error'
      end

      expect(failure).to be(true)
    end

    it 'retries the block if it raises an error' do
      attempts = 0
      max_attempts = 2
      on_failure = proc {
        attempts += 1
      }

      IvcChampva::Retry.do(max_attempts, 0, on_failure:) do
        raise StandardError, 'Standard error'
      end

      expect(attempts).to eq(max_attempts)
    end

    it 'retries the block if the error matches the retry conditions' do
      conditions = ['standard error']

      attempts = 0
      max_attempts = 2
      on_failure = proc {
        attempts += 1
      }

      IvcChampva::Retry.do(max_attempts, 0, retry_on: conditions, on_failure:) do
        raise StandardError, 'Standard Error'
      end

      expect(attempts).to eq(max_attempts)
    end

    it 'does not retry if the error does not match the retry conditions' do
      conditions = ['standard error']

      attempts = 0
      max_attempts = 2
      on_failure = proc {
        attempts += 1
      }

      IvcChampva::Retry.do(max_attempts, 0, retry_on: conditions, on_failure:) do
        raise StandardError, 'a different error'
      end

      expect(attempts).to eq(1)
    end

    it 'retries once and then succeeds' do
      num_attempts = 0
      max_attempts = 2

      result = IvcChampva::Retry.do(max_attempts, 0) do
        num_attempts += 1

        raise StandardError, 'Standard error' if num_attempts == 1

        'success'
      end

      expect(num_attempts).to eq(2)
      expect(result).to eq('success')
    end
  end
end
