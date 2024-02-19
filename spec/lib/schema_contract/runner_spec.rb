# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/schema_contract/runner'

describe SchemaContract::Runner do
  describe '.run' do
    context 'when a record already exists for the current day' do
      it 'does not create a record or enqueue a job' do
        SchemaContract::Runner.run(user: , response: {status: 200, body: {foo: 'bar'}}, test_name: 'test_index')
        
      end
    end

    context 'when no record exists for the current day' do
      it 'creates one with provided details and enqueues a job' do

      end
    end

    context 'when an error is encountered' do
      it 'logs but does not raise the error' do

      end
    end
  end
end