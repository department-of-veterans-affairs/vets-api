# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA210845 do
  it_behaves_like 'zip_code_is_us_based', %w[authorizer_address person_address organization_address]

  describe '#notification_first_name' do
    context 'preparer is veteran' do
      let(:data) do
        {
          'authorizer_type' => 'veteran',
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

    context 'preparer is non-veteran' do
      let(:data) do
        {
          'authorizer_type' => 'nonVeteran',
          'authorizer_full_name' => {
            'first' => 'Authorizer',
            'last' => 'Eteranvay'
          }
        }
      end

      it 'returns the non-veteran first name' do
        expect(described_class.new(data).notification_first_name).to eq 'Authorizer'
      end
    end
  end

  describe '#notification_email_address' do
    context 'preparer is veteran' do
      let(:data) do
        {
          'authorizer_type' => 'veteran',
          'veteran_email' => 'a@b.com'
        }
      end

      it 'returns the veteran email address' do
        expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
      end
    end

    context 'preparer is nonVeteran' do
      let(:data) do
        {
          'authorizer_type' => 'nonVeteran',
          'authorizer_email' => 'a@b.com'
        }
      end

      it 'returns the authorizer email address' do
        expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
      end
    end
  end
end
