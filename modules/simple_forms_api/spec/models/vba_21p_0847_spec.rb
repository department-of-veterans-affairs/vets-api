# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA21p0847 do
  it_behaves_like 'zip_code_is_us_based', %w[preparer_address]

  describe '#notification_first_name' do
    let(:data) do
      {
        'preparer_name' => {
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
      { 'preparer_email' => 'a@b.com' }
    end

    it 'returns the email address to be used in notifications' do
      expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
    end
  end
end
