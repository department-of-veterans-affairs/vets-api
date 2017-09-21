# frozen_string_literal: true
require 'rails_helper'

describe EMISRedis::Payment, skip_emis: true do
  let(:user) { build :loa3_user }
  subject { described_class.for_user(user) }

  describe '#receives_va_pension' do
    it 'should return true if they get retirement pay' do
      VCR.use_cassette('emis/get_retirement_pay/valid') do
        expect(subject.receives_va_pension).to eq(true)
      end
    end

    it 'should return false if they dont get retirement pay' do
      expect(subject).to receive(:items_from_response).with('get_retirement_pay').and_return([])

      expect(subject.receives_va_pension).to eq(false)
    end
  end
end
