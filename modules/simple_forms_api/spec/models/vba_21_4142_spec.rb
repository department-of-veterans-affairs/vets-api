# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA214142 do
  describe '#notification_first_name' do
    let(:data) do
      {
        'veteran' => {
          'full_name' => {
            'first' => 'Veteran',
            'last' => 'Eteranvay'
          }
        }
      }
    end

    it 'returns the first name to be used in notifications' do
      expect(described_class.new(data).notification_first_name).to eq 'Veteran'
    end
  end

  describe '#notification_email_address' do
    let(:data) do
      { 'veteran' => { 'email' => 'a@b.com' } }
    end

    it 'returns the email address to be used in notifications' do
      expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
    end
  end
end
