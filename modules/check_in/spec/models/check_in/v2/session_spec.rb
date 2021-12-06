# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::V2::Session do
  subject { described_class }

  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?)
      .with('check_in_experience_multiple_appointment_support').and_return(true)

    Rails.cache.clear
  end

  describe 'constants' do
    it 'has a UUID regex' do
      expect(subject::UUID_REGEX).to eq(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    end

    it 'has a LAST_FOUR_REGEX regex' do
      expect(subject::LAST_FOUR_REGEX).to eq(/^[0-9]{4}$/)
    end

    it 'has a LAST_NAME_REGEX regex' do
      expect(subject::LAST_NAME_REGEX).to eq(/^.{1,600}$/)
    end
  end

  describe '.build' do
    it 'returns an instance of Session' do
      expect(subject.build({})).to be_an_instance_of(CheckIn::V2::Session)
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

    it 'responds to settings' do
      expect(subject.build({}).respond_to?(:settings)).to be(true)
    end

    it 'responds to jwt' do
      expect(subject.build({}).respond_to?(:jwt)).to be(true)
    end

    it 'responds to check_in_type' do
      expect(subject.build({}).respond_to?(:check_in_type)).to be(true)
    end
  end

  describe '#valid?' do
    context 'when valid params' do
      it 'returns true' do
        params_hsh = {
          data: {
            uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            last4: '5555',
            last_name: 'Johnson',
            check_in_type: 'preCheckIn'
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

  describe '#valid_uuid?' do
    context 'when valid uuid' do
      it 'returns true' do
        params_hsh = {
          data: {
            uuid: Faker::Internet.uuid
          }
        }

        expect(subject.build(params_hsh).valid_uuid?).to be(true)
      end
    end

    context 'when invalid uuid' do
      it 'returns false' do
        params_hsh = {
          data: {
            uuid: 'd602d9eb'
          }
        }

        expect(subject.build(params_hsh).valid_uuid?).to be(false)
      end
    end
  end

  describe '#authorized?' do
    context 'when both jwt and Redis key/value present' do
      it 'returns true' do
        allow_any_instance_of(subject).to receive(:redis_session_prefix).and_return('check_in_lorota_v2')
        allow_any_instance_of(subject).to receive(:jwt).and_return('jwt-123-1bc')
        allow_any_instance_of(subject).to receive(:uuid).and_return('d602d9eb-9a31-484f-9637-13ab0b507e0d')

        Rails.cache.write(subject.build({}).key, 'jwt-123-1bc', namespace: 'check-in-lorota-v2-cache')

        expect(subject.build({}).authorized?).to eq(true)
      end
    end

    context 'when both jwt and Redis key/value absent' do
      it 'returns false' do
        allow_any_instance_of(subject).to receive(:redis_session_prefix).and_return('check_in_lorota_v2')
        allow_any_instance_of(subject).to receive(:jwt).and_return(nil)
        allow_any_instance_of(subject).to receive(:uuid).and_return('d602d9eb-9a31-484f-9637-13ab0b507e0d')

        expect(subject.build({}).authorized?).to eq(false)
      end
    end
  end

  describe '#key' do
    it 'returns a key in the proper format' do
      allow_any_instance_of(subject).to receive(:redis_session_prefix).and_return('check_in_lorota_v2')
      allow_any_instance_of(subject).to receive(:uuid).and_return('d602d9eb-9a31-484f-9637-13ab0b507e0d')

      expect(subject.build({}).key).to eq('check_in_lorota_v2_d602d9eb-9a31-484f-9637-13ab0b507e0d_read.full')
    end
  end

  describe '#unauthorized_message' do
    let(:resp) do
      {
        permissions: 'read.none',
        status: 'success',
        uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d'
      }
    end

    it 'returns a hash' do
      allow_any_instance_of(subject).to receive(:uuid).and_return('d602d9eb-9a31-484f-9637-13ab0b507e0d')

      expect(subject.build({}).unauthorized_message).to eq(resp)
    end
  end

  describe '#success_message' do
    let(:resp) do
      {
        permissions: 'read.full',
        status: 'success',
        uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d'
      }
    end

    it 'returns a hash' do
      allow_any_instance_of(subject).to receive(:uuid).and_return('d602d9eb-9a31-484f-9637-13ab0b507e0d')

      expect(subject.build({}).success_message).to eq(resp)
    end
  end

  describe '#client_error' do
    it 'has a response' do
      hsh = { error: true, message: 'Invalid last4 or last name!' }
      params_hsh = {
        id: 'd602d9eb',
        last4: '5555',
        last_name: 'Johnson'
      }
      error = subject.build(params_hsh).client_error

      expect(error).to eq(hsh)
    end
  end
end
