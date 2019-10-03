# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionActivity, type: :model do
  subject { described_class.new }

  describe 'saving' do
    describe 'originating_request_id' do
      it 'validates presence' do
        subject.valid?
        expect(subject.errors[:originating_request_id]).to include('can\'t be blank')
      end
    end

    describe 'originating_ip_address' do
      it 'validates presence' do
        subject.valid?
        expect(subject.errors[:originating_ip_address]).to include('can\'t be blank')
      end
    end

    describe 'name' do
      it 'validates presence' do
        subject.valid?
        expect(subject.errors[:originating_ip_address]).to include('can\'t be blank')
      end

      it 'validates inclusion in' do
        subject.name = 'something_not_included'
        subject.valid?
        expect(subject.errors[:name]).to include('is not included in the list')
        subject.name = 'signup'
        subject.valid?
        expect(subject.errors[:name]).to be_empty
      end
    end

    describe 'status' do
      it 'validates presence' do
        subject.valid?
        expect(subject.errors[:originating_ip_address]).to include('can\'t be blank')
      end

      it 'validates inclusion in' do
        subject.status = 'something_not_included'
        subject.valid?
        expect(subject.errors[:status]).to include('is not included in the list')
        subject.status = 'incomplete'
        subject.valid?
        expect(subject.errors[:status]).to be_empty
      end
    end

    it 'a model can be valid' do
      session_activity = FactoryBot.build(:session_activity)
      expect(session_activity).to be_valid
    end
  end
end
