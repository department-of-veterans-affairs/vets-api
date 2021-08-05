# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::PatientCheckIn do
  subject { described_class }

  describe 'constants' do
    it 'has a UUID regex' do
      expect(subject::UUID_REGEX).to eq(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    end
  end

  describe '.build' do
    it 'returns an instance of PatientCheckIn' do
      expect(subject.build({})).to be_an_instance_of(CheckIn::PatientCheckIn)
    end
  end

  describe 'attributes' do
    it 'responds to uud' do
      expect(subject.build({}).respond_to?(:uuid)).to be(true)
    end
  end

  describe '#valid?' do
    context 'when valid uuid' do
      it 'returns true' do
        expect(subject.build({ uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }).valid?).to be(true)
      end
    end

    context 'when invalid uuid' do
      it 'returns false' do
        expect(subject.build({ uuid: 'd602d9eb' }).valid?).to be(false)
      end
    end
  end

  describe '#client_error' do
    it 'has a response' do
      hsh = { error: true, message: 'Invalid uuid d602d9eb' }
      error = subject.build({ uuid: 'd602d9eb' }).client_error

      expect(error.body).to eq(hsh)
      expect(error.status).to eq(400)
    end
  end
end
