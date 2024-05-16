# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::FlaggedVeteranRepresentativeContactData, type: :model do
  describe 'validations' do
    context 'ip_address' do
      it 'is valid when ip_address is present' do
        flag = described_class.new(ip_address: '192.168.1.1', representative_id: '1', flag_type: 'phone_number',
                                   flagged_value: '1234567890')
        expect(flag).to be_valid
      end

      it 'is not valid when ip_address is missing' do
        flag = described_class.new(ip_address: nil, representative_id: '1', flag_type: 'phone_number',
                                   flagged_value: '1234567890')
        expect(flag).not_to be_valid
        expect(flag.errors[:ip_address]).to include("can't be blank")
      end
    end

    context 'representative_id' do
      it 'is valid when representative_id is present' do
        flag = described_class.new(ip_address: '192.168.1.1', representative_id: '1', flag_type: 'phone_number',
                                   flagged_value: '1234567890')
        expect(flag).to be_valid
      end

      it 'is not valid when representative_id is missing' do
        flag = described_class.new(ip_address: '192.168.1.1', representative_id: nil, flag_type: 'phone_number',
                                   flagged_value: '1234567890')
        expect(flag).not_to be_valid
        expect(flag.errors[:representative_id]).to include("can't be blank")
      end
    end

    context 'flag_type' do
      it 'is valid with a valid flag_type' do
        %w[phone_number email address other].each do |flag_type|
          flag = described_class.new(ip_address: '192.168.1.1', representative_id: '1', flag_type:,
                                     flagged_value: "#{flag_type} value")
          expect(flag).to be_valid
        end
      end

      it 'raises ArgumentError with an invalid flag_type' do
        expect do
          described_class.new(ip_address: '192.168.1.1', representative_id: '1', flag_type: 'invalid_type',
                              flagged_value: 'invalid_type value')
        end.to raise_error(ArgumentError, /is not a valid flag_type/)
      end
    end

    context 'uniqueness' do
      before do
        described_class.create!(ip_address: '192.168.1.1', representative_id: '1', flag_type: 'email',
                                flagged_value: 'example@email.com')
      end

      it 'is invalid when duplicating ip_address, representative_id, and flag_type of an existing record' do
        duplicate = described_class.new(ip_address: '192.168.1.1', representative_id: '1', flag_type: 'email',
                                        flagged_value: 'example@email.com')
        expect(duplicate).not_to be_valid
      end

      it 'is valid when changing only the ip_address while keeping representative_id and flag_type same' do
        unique = described_class.new(ip_address: '192.168.1.2', representative_id: '1', flag_type: 'email',
                                     flagged_value: 'example@email.com')
        expect(unique).to be_valid
      end

      it 'is valid when changing only the representative_id while keeping ip_address and flag_type same' do
        unique = described_class.new(ip_address: '192.168.1.1', representative_id: '2', flag_type: 'email',
                                     flagged_value: 'example@email.com')
        expect(unique).to be_valid
      end

      it 'is valid when changing only the flag_type while keeping ip_address and representative_id same' do
        unique = described_class.new(ip_address: '192.168.1.1', representative_id: '1', flag_type: 'phone_number',
                                     flagged_value: 'example@email.com')
        expect(unique).to be_valid
      end
    end
  end
end
