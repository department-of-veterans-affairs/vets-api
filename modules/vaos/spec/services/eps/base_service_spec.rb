# frozen_string_literal: true

require 'rails_helper'

describe Eps::BaseService do
  user_icn = '123456789V123456'

  let(:user) { double('User', account_uuid: '1234', icn: user_icn) }
  let(:service) { described_class.new(user) }

  describe '#config' do
    it 'returns the Eps::Configuration instance' do
      expect(service.config).to be_instance_of(Eps::Configuration)
    end
  end

  describe '#patient_id' do
    it 'returns the user ICN' do
      expect(service.send(:patient_id)).to eq(user_icn)
    end

    it 'memoizes the ICN' do
      expect(user).to receive(:icn).once.and_return(user_icn)
      2.times { service.send(:patient_id) }
    end
  end
end
