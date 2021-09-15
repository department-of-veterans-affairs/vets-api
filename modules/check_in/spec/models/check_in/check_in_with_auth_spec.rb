# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::CheckInWithAuth do
  subject { described_class }

  describe 'constants' do
    it 'has a LAST_FOUR_REGEX regex' do
      expect(subject::LAST_FOUR_REGEX).to eq(/^[0-9]{4}$/)
    end

    it 'has a LAST_NAME_REGEX regex' do
      expect(subject::LAST_NAME_REGEX).to eq(/^.{1,600}$/)
    end
  end

  describe '.build' do
    it 'returns an instance of CheckInWithAuth' do
      expect(subject.build({})).to be_an_instance_of(CheckIn::CheckInWithAuth)
    end
  end

  describe 'attributes' do
    it 'responds to uuid' do
      expect(subject.build({}).respond_to?(:uuid)).to be(true)
    end

    it 'responds to last4' do
      expect(subject.build({}).respond_to?(:last4)).to be(true)
    end

    it 'responds to last_name' do
      expect(subject.build({}).respond_to?(:last_name)).to be(true)
    end
  end

  describe '#valid?' do
    context 'when valid params' do
      it 'returns true' do
        params_hsh = {
          data: {
            uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            last4: '5555',
            last_name: 'Johnson'
          }
        }

        expect(subject.build(params_hsh).valid?).to be(true)
      end
    end

    context 'when invalid uuid' do
      it 'returns false' do
        params_hsh = {
          uuid: 'd602d9eb',
          last4: '5555',
          last_name: 'Johnson'
        }

        expect(subject.build(params_hsh).valid?).to be(false)
      end
    end
  end

  describe '#client_error' do
    it 'has a response' do
      hsh = { error: true, message: 'Invalid uuid, last4 or last name!' }
      params_hsh = {
        id: 'd602d9eb',
        last4: '5555',
        last_name: 'Johnson'
      }
      error = subject.build(params_hsh).client_error

      expect(error.body).to eq(hsh)
      expect(error.status).to eq(400)
    end
  end
end
