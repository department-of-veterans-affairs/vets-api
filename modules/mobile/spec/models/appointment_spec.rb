# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::Appointment, type: :model do
  describe '.convert_from_non_prod_id!' do
    it 'converts mocked ids to real ones' do
      expect(Mobile::V0::Appointment.convert_from_non_prod_id!('983')).to eq('442')
    end

    it 'does not change id when already valid' do
      expect(Mobile::V0::Appointment.convert_from_non_prod_id!('442')).to eq('442')
    end

    it 'keeps secondary identifiers' do
      expect(Mobile::V0::Appointment.convert_from_non_prod_id!('983GC')).to eq('442GC')
    end

    context 'when in production' do
      before { allow(Settings).to receive(:hostname).and_return('api.va.gov') }

      it 'does not convert mocked ids' do
        expect(Mobile::V0::Appointment.convert_from_non_prod_id!('983')).to eq('983')
      end
    end
  end

  describe '.convert_to_non_prod_id!' do
    it 'converts real ids to mocked ones' do
      expect(Mobile::V0::Appointment.convert_to_non_prod_id!('442')).to eq('983')
    end

    it 'does not change id when already mocked value' do
      expect(Mobile::V0::Appointment.convert_to_non_prod_id!('983')).to eq('983')
    end

    it 'keeps secondary identifiers' do
      expect(Mobile::V0::Appointment.convert_to_non_prod_id!('442GC')).to eq('983GC')
    end

    context 'when in production' do
      before { allow(Settings).to receive(:hostname).and_return('api.va.gov') }

      it 'does not convert real ids' do
        expect(Mobile::V0::Appointment.convert_to_non_prod_id!('442')).to eq('442')
      end
    end
  end
end
