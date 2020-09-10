# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app/services/covid_research/volunteer/form_crypto_service.rb'
require_relative '../../../covid_research_spec_helper.rb'

RSpec.configure do |c|
  c.include CovidResearchSpecHelper
end

RSpec.describe CovidResearch::Volunteer::FormCryptoService do
  let(:subject)        { described_class.new }
  let(:raw_form)       { read_fixture('valid-submission.json') }
  let(:encoded)        { JSON.parse(read_fixture('encrypted-form.json')) }
  let(:encrypted_form) { Base64.decode64(encoded['form_data']) }
  let(:iv)             { Base64.decode64(encoded['iv']) }

  context 'encryption' do
    it 'encrypts the form' do
      expect(subject.encrypt_form(raw_form)[:form_data]).not_to eq(raw_form)
    end
  end

  context 'decryption' do
    it 'decrypts to a known value when given the iv' do
      actual = JSON.parse(subject.decrypt_form(encrypted_form, iv))
      expected = JSON.parse(raw_form)

      expect(actual).to eq(expected)
    end
  end
end
