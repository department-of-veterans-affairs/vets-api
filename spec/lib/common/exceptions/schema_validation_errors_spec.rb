# frozen_string_literal: true

require 'spec_helper'
require 'common/exceptions'

describe Common::Exceptions::SchemaValidationErrors do
  context 'with resource that has no errors provided' do
    it do
      expect { described_class.new([]) }
        .to raise_error(TypeError, 'the resource provided has no errors')
    end
  end

  context 'with resource having errors provided' do
    subject { described_class.new(['error 1']) }

    it 'should format the errors correctly' do
      errors = subject.errors

      expect(errors.size).to eq(1)
      expect(errors[0].to_hash).to eq(
        title: 'Validation error', detail: 'error 1', code: '109', status: '422'
      )
    end
  end
end
