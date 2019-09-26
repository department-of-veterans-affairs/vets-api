# frozen_string_literal: true

require 'rails_helper'

describe VAOS::JWT do

  let(:user) { build(:user, :mhv) }
  subject { VAOS::JWT.new(user) }

  describe '.new' do
    it 'creates a VAOS::JWT instance' do
      expect(subject).to be_an_instance_of(VAOS::JWT)
    end
  end

  describe '#token' do
    it 'encodes a token' do
      expect(subject.token).to eq('funk')
    end
  end
end
