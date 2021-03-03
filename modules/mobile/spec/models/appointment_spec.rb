# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::Appointment, type: :model do
  describe '.toggle_non_prod_id!' do
    it 'toggles mocked ids to real ones' do
      expect(Mobile::V0::Appointment.toggle_non_prod_id!('983')).to eq('442')
    end

    it 'toggles real ids back to mocked ones' do
      expect(Mobile::V0::Appointment.toggle_non_prod_id!('442')).to eq('983')
    end

    it 'keeps secondary identifiers' do
      expect(Mobile::V0::Appointment.toggle_non_prod_id!('983GC')).to eq('442GC')
    end
  end
end
