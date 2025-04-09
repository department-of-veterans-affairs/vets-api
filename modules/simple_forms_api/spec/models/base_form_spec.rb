# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::BaseForm do
  describe '#notification_first_name' do
    it 'returns the first name to be used in notifications' do
      data = {
        'veteran_full_name' => {
          'first' => 'Veteran',
          'last' => 'Eteranvay'
        }
      }

      expect(described_class.new(data).notification_first_name).to eq 'Veteran'
    end
  end

  describe '#notification_email_address' do
    it 'returns the email address to be used in notifications' do
      data = { 'veteran' => { 'email' => 'a@b.com' } }

      expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
    end
  end

  describe '#should_send_to_point_of_contact?' do
    it 'returns false' do
      expect(described_class.new({}).should_send_to_point_of_contact?).to be false
    end
  end
end
