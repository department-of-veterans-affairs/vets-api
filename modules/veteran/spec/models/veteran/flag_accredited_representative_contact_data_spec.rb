# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Veteran::FlaggedVeteranRepresentativeContactData, type: :model do
  describe 'validations' do
    subject do
      described_class.new(ip_address: '192.168.1.1', representative_id: '1', flag_type: 'email')
    end

    context 'flag_type' do
      it 'is valid with a valid flag_type' do
        expect(subject).to be_valid
      end

      it 'is not valid with an invalid flag_type' do
        subject.flag_type = 'invalid_type'
        expect(subject).not_to be_valid
      end
    end

    context 'uniqueness' do
      before { described_class.create!(ip_address: '192.168.1.1', representative_id: '1', flag_type: 'email') }

      it 'is not valid with a duplicate combination of ip_address, representative_id, and flag_type' do
        duplicate = described_class.new(ip_address: '192.168.1.1', representative_id: '1', flag_type: 'email')
        expect(duplicate).not_to be_valid
      end

      it 'is valid with a unique combination of ip_address, representative_id, and flag_type' do
        unique = described_class.new(ip_address: '192.168.1.2', representative_id: '1', flag_type: 'email')
        expect(unique).to be_valid
      end
    end
  end
end
