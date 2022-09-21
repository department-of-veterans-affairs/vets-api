# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VirtualAgentUserAccessRecord, type: :model do
  subject do
    described_class.new(id: 'id',
                        action_type: 'claims',
                        first_name: 'first_name',
                        last_name: 'last_name',
                        ssn: 'ssn',
                        icn: 'icn')
  end

  describe 'Validations' do
    it 'is valid with valid attributes' do
      expect(subject).to be_valid
    end

    it 'is not valid without an id' do
      subject.id = nil
      expect(subject).not_to be_valid
    end

    it 'is not valid without an action_type' do
      subject.action_type = nil
      expect(subject).not_to be_valid
    end

    it 'is not valid without a first_name' do
      subject.first_name = nil
      expect(subject).not_to be_valid
    end

    it 'is not valid without a last_name' do
      subject.last_name = nil
      expect(subject).not_to be_valid
    end

    it 'is not valid without a ssn' do
      subject.ssn = nil
      expect(subject).not_to be_valid
    end

    it 'is not valid without an icn' do
      subject.icn = nil
      expect(subject).not_to be_valid
    end
  end
end
