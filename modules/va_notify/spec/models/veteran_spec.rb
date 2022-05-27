# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VANotify::Veteran, type: :model do
  describe '#initialize' do
    it 'instantiates a claims veteran' do
      subject = VANotify::Veteran.new(
        first_name: 'Melvin',
        user_uuid: 'user_uuid'
      )

      account = double('Account')
      allow(Account).to receive(:lookup_by_user_uuid).and_return(account)
      allow(account).to receive(:icn).and_return('icn')

      expect(subject.first_name).to eq('Melvin')
      expect(subject.icn).to eq('icn')
    end
  end
end
