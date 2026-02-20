# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailVerificationSerializer, type: :serializer do
  describe 'status response' do
    let(:response_data) do
      OpenStruct.new(
        id: SecureRandom.uuid,
        needs_verification: true
      )
    end

    let(:serialized_data) do
      described_class.new(response_data, status: 'unverified')
    end

    let(:serialized_hash) { serialized_data.serializable_hash }

    it 'includes correct type' do
      expect(serialized_hash[:data][:type]).to eq :email_verification
    end

    it 'includes id field' do
      expect(serialized_hash[:data][:id]).to be_present
      expect(serialized_hash[:data][:id]).to eq response_data.id
    end

    it 'includes needs_verification attribute' do
      expect(serialized_hash[:data][:attributes][:needs_verification]).to be true
    end

    it 'includes status attribute' do
      expect(serialized_hash[:data][:attributes][:status]).to eq('unverified')
    end

    it 'excludes other response type attributes' do
      attributes = serialized_hash[:data][:attributes]
      expect(attributes).not_to have_key(:email_sent)
      expect(attributes).not_to have_key(:template_type)
      expect(attributes).not_to have_key(:verified)
      expect(attributes).not_to have_key(:verified_at)
    end

    context 'when verification is not needed' do
      let(:response_data) do
        OpenStruct.new(
          id: SecureRandom.uuid,
          needs_verification: false
        )
      end

      let(:serialized_data) do
        described_class.new(response_data, status: 'verified')
      end

      it 'returns false for needs_verification' do
        expect(serialized_hash[:data][:attributes][:needs_verification]).to be false
      end

      it 'includes needs_verification key even when false' do
        expect(serialized_hash[:data][:attributes]).to have_key(:needs_verification)
        expect(serialized_hash[:data][:attributes][:needs_verification]).to be false
      end

      it 'includes status attribute' do
        expect(serialized_hash[:data][:attributes][:status]).to eq('verified')
      end
    end
  end

  describe 'sent response' do
    let(:template_type) { 'reminder_verification' }
    let(:response_data) do
      OpenStruct.new(
        id: SecureRandom.uuid,
        email_sent: true,
        template_type:
      )
    end

    let(:serialized_data) do
      described_class.new(response_data, sent: true)
    end

    let(:serialized_hash) { serialized_data.serializable_hash }

    it 'includes correct type' do
      expect(serialized_hash[:data][:type]).to eq :email_verification
    end

    it 'includes id field' do
      expect(serialized_hash[:data][:id]).to be_present
      expect(serialized_hash[:data][:id]).to eq response_data.id
    end

    it 'includes email_sent attribute' do
      expect(serialized_hash[:data][:attributes][:email_sent]).to be true
    end

    it 'includes template_type attribute' do
      expect(serialized_hash[:data][:attributes][:template_type]).to eq template_type
    end

    it 'excludes other response type attributes' do
      attributes = serialized_hash[:data][:attributes]
      expect(attributes).not_to have_key(:needs_verification)
      expect(attributes).not_to have_key(:verified)
      expect(attributes).not_to have_key(:verified_at)
    end

    context 'with default template type' do
      let(:response_data) do
        OpenStruct.new(
          id: SecureRandom.uuid,
          email_sent: true,
          template_type: 'initial_verification'
        )
      end

      it 'uses initial_verification as default' do
        expect(serialized_hash[:data][:attributes][:template_type]).to eq 'initial_verification'
      end
    end
  end

  describe 'verified response' do
    let(:verification_time) { Time.zone.parse('2026-01-15T10:00:00Z') }
    let(:response_data) do
      OpenStruct.new(
        id: SecureRandom.uuid,
        verified: true,
        verified_at: verification_time
      )
    end

    let(:serialized_data) do
      described_class.new(response_data, verified: true)
    end

    let(:serialized_hash) { serialized_data.serializable_hash }

    it 'includes correct type' do
      expect(serialized_hash[:data][:type]).to eq :email_verification
    end

    it 'includes id field' do
      expect(serialized_hash[:data][:id]).to be_present
      expect(serialized_hash[:data][:id]).to eq response_data.id
    end

    it 'includes verified attribute' do
      expect(serialized_hash[:data][:attributes][:verified]).to be true
    end

    it 'includes verified_at attribute' do
      expect(serialized_hash[:data][:attributes][:verified_at]).to eq verification_time
    end

    it 'excludes other response type attributes' do
      attributes = serialized_hash[:data][:attributes]
      expect(attributes).not_to have_key(:needs_verification)
      expect(attributes).not_to have_key(:email_sent)
      expect(attributes).not_to have_key(:template_type)
    end

    context 'with current time default' do
      let(:response_data) do
        OpenStruct.new(
          id: SecureRandom.uuid,
          verified: true,
          verified_at: Time.current
        )
      end

      it 'uses current time when no verified_at provided' do
        expect(serialized_hash[:data][:attributes][:verified_at]).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe 'invalid response type' do
    let(:response_data) do
      OpenStruct.new(
        id: SecureRandom.uuid,
        needs_verification: true
      )
    end

    let(:serialized_data) do
      described_class.new(response_data)
    end

    let(:serialized_hash) { serialized_data.serializable_hash }

    it 'includes id field' do
      expect(serialized_hash[:data][:id]).to be_present
    end

    it 'excludes all conditional attributes when no flag is provided' do
      attributes = serialized_hash[:data][:attributes]
      expect(attributes).not_to have_key(:needs_verification)
      expect(attributes).not_to have_key(:email_sent)
      expect(attributes).not_to have_key(:template_type)
      expect(attributes).not_to have_key(:verified)
      expect(attributes).not_to have_key(:verified_at)
    end
  end

  describe 'resource validation' do
    let(:valid_response_data) do
      OpenStruct.new(
        id: SecureRandom.uuid,
        needs_verification: true
      )
    end

    context 'when resource is nil' do
      it 'raises ArgumentError' do
        expect do
          described_class.new(nil, status: 'verified')
        end.to raise_error(ArgumentError, 'Resource cannot be nil')
      end
    end

    context 'when resource does not respond to id' do
      let(:resource_without_id) do
        object = Object.new
        object.define_singleton_method(:needs_verification) { true }
        object
      end

      it 'raises ArgumentError' do
        expect do
          described_class.new(resource_without_id, status: 'verified')
        end.to raise_error(ArgumentError, 'Resource must respond to :id method for serialization')
      end
    end

    context 'when resource does not respond to any email verification methods' do
      let(:invalid_resource) do
        OpenStruct.new(id: SecureRandom.uuid, some_other_attribute: 'value')
      end

      it 'raises ArgumentError with method list' do
        expect do
          described_class.new(invalid_resource, status: 'verified')
        end.to raise_error(ArgumentError, /Resource must respond to at least one email verification method:/)
      end
    end

    context 'when resource responds to at least one verification method' do
      let(:minimal_valid_resource) do
        OpenStruct.new(id: SecureRandom.uuid, needs_verification: false)
      end

      it 'does not raise error' do
        expect do
          described_class.new(minimal_valid_resource, status: 'verified')
        end.not_to raise_error
      end
    end

    context 'when resource responds to multiple verification methods' do
      let(:full_resource) do
        OpenStruct.new(
          id: SecureRandom.uuid,
          needs_verification: true,
          email_sent: true,
          template_type: 'test',
          verified: false,
          verified_at: nil
        )
      end

      it 'does not raise error' do
        expect do
          described_class.new(full_resource, status: 'verified')
        end.not_to raise_error
      end
    end
  end

  describe 'response type validation' do
    let(:response_data) do
      OpenStruct.new(
        id: SecureRandom.uuid,
        needs_verification: true,
        email_sent: true
      )
    end

    context 'when multiple flags are provided' do
      it 'raises ArgumentError when two flags are provided' do
        expect do
          described_class.new(response_data, status: 'verified', sent: true).serializable_hash
        end.to raise_error(ArgumentError,
                           /EmailVerificationSerializer expects exactly one of.*to be set/)
      end

      it 'raises ArgumentError when all three flags are provided' do
        expect do
          described_class.new(response_data, status: 'verified', sent: true, verified: true).serializable_hash
        end.to raise_error(ArgumentError,
                           /EmailVerificationSerializer expects exactly one of.*to be set/)
      end
    end

    context 'when non-boolean values are provided' do
      it 'accepts present string values' do
        serialized_data = described_class.new(response_data, status: 'verified')
        attributes = serialized_data.serializable_hash[:data][:attributes]

        expect(attributes).to have_key(:needs_verification)
        expect(attributes).to have_key(:status)
      end

      it 'accepts any present value for mode detection' do
        serialized_data = described_class.new(response_data, status: 'unverified')
        attributes = serialized_data.serializable_hash[:data][:attributes]

        expect(attributes).to have_key(:needs_verification)
        expect(attributes).to have_key(:status)
      end

      it 'ignores nil status (no mode selected)' do
        serialized_data = described_class.new(response_data, status: nil)
        attributes = serialized_data.serializable_hash[:data][:attributes]

        expect(attributes).not_to have_key(:needs_verification)
        expect(attributes).not_to have_key(:status)
      end
    end
  end
end
