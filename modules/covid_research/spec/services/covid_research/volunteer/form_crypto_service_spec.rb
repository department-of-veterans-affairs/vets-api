# frozen_string_literal: true

require 'rails_helper'
require CovidResearch::Engine.root.join('spec', 'rails_helper.rb')

RSpec.describe CovidResearch::Volunteer::FormCryptoService do
  let(:subject)        { described_class.new }
  let(:raw_form)       { read_fixture('valid-submission.json') }
  # Rebuild this by running `rake rebuild_encrypted_fixture` when changing the encryption keys
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
