# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA2010206 do
  it_behaves_like 'zip_code_is_us_based', %w[address]

  describe '#notification_first_name' do
    let(:data) do
      {
        'full_name' => {
          'first' => 'Veteran',
          'last' => 'Eteranvay'
        }
      }
    end

    it 'returns the first name to be used in notifications' do
      expect(described_class.new(data).notification_first_name).to eq 'Veteran'
    end
  end

  describe '#notification_email_address' do
    let(:data) do
      { 'email_address' => 'a@b.com' }
    end

    it 'returns the email address to be used in notifications' do
      expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
    end
  end
end
