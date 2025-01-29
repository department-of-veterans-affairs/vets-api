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
end
