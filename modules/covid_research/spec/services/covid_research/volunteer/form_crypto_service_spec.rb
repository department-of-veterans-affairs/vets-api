# frozen_string_literal: true

require 'rails_helper'
require CovidResearch::Engine.root.join('spec', 'rails_helper.rb')

RSpec.describe CovidResearch::Volunteer::FormCryptoService do
  let(:subject) { described_class.new }
  let(:raw_intake_form)       { read_fixture('valid-intake-submission.json') }
  let(:raw_update_form)       { read_fixture('valid-update-submission.json') }

  # run rake rebuild_encrypted_fixture to rebuild the below
  let(:encoded)        { JSON.parse(read_fixture('encrypted-form.json')) }
  let(:encrypted_form) { Base64.decode64(encoded['form_data']) }

  let(:encoded_update)        { JSON.parse(read_fixture('encrypted-update-form.json')) }
  let(:encrypted_update_form) { Base64.decode64(encoded_update['form_data']) }

  context 'encryption' do
    it 'encrypts the inital form' do
      expect(subject.encrypt_form(raw_intake_form)[:form_data]).not_to eq(raw_intake_form)
    end

    it 'encrypts the update form' do
      expect(subject.encrypt_form(raw_update_form)[:form_data]).not_to eq(raw_update_form)
    end
  end

  context 'decryption' do
    it 'decrypts intake form to a known value using the lockbox value' do
      actual = JSON.parse(subject.decrypt_form(encrypted_form))
      expected = JSON.parse(raw_intake_form)

      expect(actual).to eq(expected)
    end

    it 'decrypts update form to a known value using the lockbox value' do
      actual = JSON.parse(subject.decrypt_form(encrypted_update_form))
      expected = JSON.parse(raw_update_form)

      expect(actual).to eq(expected)
    end
  end
end
