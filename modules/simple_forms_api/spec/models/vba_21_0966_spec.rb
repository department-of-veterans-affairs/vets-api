# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA210966 do
  it_behaves_like 'zip_code_is_us_based', %w[veteran_mailing_address surviving_dependent_mailing_address]

  describe 'populate_veteran_data' do
    context 'data does not already have what it needs' do
      let(:expected_first_name) { 'Rory' }
      let(:expected_last_name) { 'Stewart' }
      let(:expected_address) do
        {
          'postal_code' => '12345'
        }
      end
      let(:expected_ssn) { 'fake-ssn' }
      let(:user) { create(:user, first_name: expected_first_name, last_name: expected_last_name, ssn: expected_ssn) }
      let(:data) { {} }

      it 'pulls the data from the user' do
        allow(user).to receive(:address).and_return(expected_address)

        form = SimpleFormsApi::VBA210966.new(data).populate_veteran_data(user)

        expect(form.data['veteran_full_name']).to eq({ 'first' => expected_first_name, 'last' => expected_last_name })
        expect(form.data['veteran_mailing_address']).to eq expected_address
        expect(form.data['veteran_id']).to eq({ 'ssn' => expected_ssn })
      end
    end

    context 'data already has what it needs' do
      let(:expected_address) do
        {
          'postal_code' => '12345'
        }
      end
      let(:expected_full_name) { { 'first' => 'John', 'last' => 'Darwin' } }
      let(:expected_ssn) { 'fake-ssn' }
      let(:user) { create(:user) }
      let(:data) do
        { 'veteran_full_name' => expected_full_name, 'veteran_mailing_address' => expected_address,
          'veteran_id' => { 'ssn' => expected_ssn } }
      end

      it 'pulls the data from the form' do
        form = SimpleFormsApi::VBA210966.new(data).populate_veteran_data(user)

        expect(form.data['veteran_full_name']).to eq(expected_full_name)
        expect(form.data['veteran_mailing_address']).to eq expected_address
        expect(form.data['veteran_id']).to eq({ 'ssn' => expected_ssn })
      end
    end
  end

  describe '#notification_first_name' do
    context 'preparer is surviving dependent' do
      let(:data) do
        {
          'preparer_identification' => 'SURVIVING_DEPENDENT',
          'surviving_dependent_full_name' => {
            'first' => 'Surviving',
            'last' => 'Dependent'
          }
        }
      end

      it 'returns the surviving dependent first name' do
        expect(described_class.new(data).notification_first_name).to eq 'Surviving'
      end
    end

    context 'preparer is not the surviving dependent' do
      let(:data) do
        {
          'preparer_identification' => 'VETERAN',
          'veteran_full_name' => {
            'first' => 'Veteran',
            'last' => 'Eteranvay'
          }
        }
      end

      it 'returns the veteran first name' do
        expect(described_class.new(data).notification_first_name).to eq 'Veteran'
      end
    end
  end

  describe '#notification_email_address' do
    context 'preparer is surviving dependent' do
      let(:data) do
        {
          'preparer_identification' => 'SURVIVING_DEPENDENT',
          'surviving_dependent_email' => 'a@b.com'
        }
      end

      it 'returns the surviving dependent email address' do
        expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
      end
    end

    context 'preparer is anyone else' do
      let(:data) do
        {
          'preparer_identification' => 'space-alien',
          'veteran_email' => 'a@b.com'
        }
      end

      it 'returns the veteran email address' do
        expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
      end
    end
  end
end
