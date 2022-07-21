# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::Appointment, type: :model do
  describe '.convert_non_prod_id!' do
    it 'converts mocked ids to real ones' do
      expect(Mobile::V0::Appointment.convert_non_prod_id!('983')).to eq('442')
    end

    it 'does not change id when already valid' do
      expect(Mobile::V0::Appointment.convert_non_prod_id!('442')).to eq('442')
    end

    it 'keeps secondary identifiers' do
      expect(Mobile::V0::Appointment.convert_non_prod_id!('983GC')).to eq('442GC')
    end

    context 'when in production' do
      before do
        @original_hostname = Settings.hostname
        Settings.hostname = 'api.va.gov'
      end

      after { Settings.hostname = @original_hostname }

      it 'does not convert mocked ids' do
        expect(Mobile::V0::Appointment.convert_non_prod_id!('983')).to eq('983')
      end
    end
  end
end
