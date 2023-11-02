# frozen_string_literal: true

require 'rails_helper'

describe Avs::V0::AvsService do
  subject { described_class.new }

  describe 'get_avs_base_url' do
    it 'returns the correct path' do
      path = subject.get_avs_base_url('test_sid')
      expect(path).to eq('avs/test_sid')
    end
  end

  describe 'get_avs_by_appointment_url' do
    it 'returns the correct path' do
      path = subject.get_avs_by_appointment_url('500', '123456')
      expect(path).to eq('avs-by-appointment/500/123456')
    end
  end
end
