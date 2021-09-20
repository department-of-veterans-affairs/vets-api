# frozen_string_literal: true

require 'rails_helper'
require CovidResearch::Engine.root.join('spec', 'rails_helper.rb')

RSpec.describe CovidResearch::Volunteer::FormCryptoService do
  let(:subject)        { described_class.new }
  let(:raw_form)       { read_fixture('valid-submission.json') }
  # run rake rebuild_encrypted_fixture to rebuild the below
  let(:encoded)        { JSON.parse(read_fixture('encrypted-form.json')) }
  let(:encrypted_form) { Base64.decode64(encoded['form_data']) }

  context 'encryption' do
    it 'encrypts the form' do
      expect(subject.encrypt_form(raw_form)[:form_data]).not_to eq(raw_form)
    end
  end

  context 'decryption' do
    it 'decrypts to a known value using the lockbox value' do
      actual = JSON.parse(subject.decrypt_form(encrypted_form))
      expected = JSON.parse(raw_form)

      expect(actual).to eq(expected)
    end
  end
end
