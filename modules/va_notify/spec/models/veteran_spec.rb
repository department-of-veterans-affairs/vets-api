# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VANotify::Veteran, type: :model do
  describe 'icn lookup' do
    let(:user_uuid_with_hyphens) do
      '11111111-2222-3333-4444-555555555555'
    end

    let(:user_uuid_without_hyphens) do
      user_uuid_with_hyphens.gsub('-', '')
    end

    it 'checks with plain uuid first' do
      account = double('Account')
      allow(Account).to receive(:lookup_by_user_uuid).and_return(account)
      allow(account).to receive(:icn).and_return('icn')

      subject = VANotify::Veteran.new(
        first_name: 'Melvin',
        user_uuid: user_uuid_without_hyphens
      )

      expect(subject.first_name).to eq('Melvin')
      expect(subject.icn).to eq('icn')

      expect(Account).to have_received(:lookup_by_user_uuid).with(user_uuid_without_hyphens)
      expect(Account).not_to have_received(:lookup_by_user_uuid).with(user_uuid_with_hyphens)
    end

    it 'checks with hyphens if the first lookup returns nil' do
      account = double('Account')
      allow(Account).to receive(:lookup_by_user_uuid).and_return(nil, account)
      allow(account).to receive(:icn).and_return('icn')

      subject = VANotify::Veteran.new(
        first_name: 'Melvin',
        user_uuid: user_uuid_without_hyphens
      )

      expect(subject.first_name).to eq('Melvin')
      expect(subject.icn).to eq('icn')

      expect(Account).to have_received(:lookup_by_user_uuid).with(user_uuid_without_hyphens)
      expect(Account).to have_received(:lookup_by_user_uuid).with(user_uuid_with_hyphens)
    end

    it 'returns nil if no matching account is found' do
      allow(Account).to receive(:lookup_by_user_uuid).and_return(nil, nil)

      subject = VANotify::Veteran.new(
        first_name: 'Melvin',
        user_uuid: user_uuid_without_hyphens
      )

      expect(subject.first_name).to eq('Melvin')
      expect(subject.icn).to be nil

      expect(Account).to have_received(:lookup_by_user_uuid).with(user_uuid_without_hyphens)
      expect(Account).to have_received(:lookup_by_user_uuid).with(user_uuid_with_hyphens)
    end
  end
end
