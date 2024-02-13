# frozen_string_literal: true

require 'rails_helper'
require 'lib/schema_contract/validator'

describe SchemaContract::Validator do
  describe '#validate' do
    context 'when response matches schema' do
      it 'updates record' do

      end

      it 'does not log errors' do

      end
    end

    describe 'when response does not match schema' do
      # test various error types
    end

    context 'when schema contract does not exist in db' do

    end

    context 'when schema file does not exist' do

    end

    context 'when schema file is invalid' do

    end
  end
end