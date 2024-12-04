# frozen_string_literal: true

require 'spec_helper'
require_relative '../simple_forms_api/form_remediation/error'

RSpec.describe SimpleFormsApi::FormRemediation::Error do
  let(:instance) { described_class.new }

  describe '#message' do
    subject(:message) { instance.message }

    it 'does something useful' do
      expect(message).to eq(true)
    end
  end

  describe '#backtrace' do
    subject(:backtrace) { instance.backtrace }

    it 'does something useful' do
      expect(backtrace).to eq(true)
    end
  end

  describe '#base_error' do
    subject(:base_error) { instance.base_error }

    it 'does something useful' do
      expect(base_error).to eq(true)
    end
  end

  describe '#details' do
    subject(:details) { instance.details }

    it 'does something useful' do
      expect(details).to eq(true)
    end
  end
end
