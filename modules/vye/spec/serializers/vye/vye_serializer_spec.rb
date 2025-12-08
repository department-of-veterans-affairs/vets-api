# frozen_string_literal: true

require 'rails_helper'
require 'vye/vye_serializer'

# rubocop:disable RSpec/MultipleDescribes
RSpec.describe Vye::ClaimantLookupSerializer, type: :serializer do
  subject { described_class.new(response) }

  let(:response) { build_stubbed(:claimant_lookup_response) }
  let(:serialized_json) { subject.to_json }
  let(:parsed_json) { JSON.parse(serialized_json) }

  describe '#serializable_hash' do
    it 'includes claimant_id' do
      expect(subject.serializable_hash[:claimant_id]).to eq response.claimant_id
    end
  end

  describe '#to_json' do
    it 'includes claimant_id' do
      expect(parsed_json['claimant_id']).to eq response.claimant_id
    end

    it 'returns valid JSON' do
      expect { JSON.parse(serialized_json) }.not_to raise_error
    end
  end

  describe '#status' do
    it 'returns the response status' do
      expect(subject.status).to eq response.status
    end
  end
end

RSpec.describe Vye::ClaimantVerificationSerializer, type: :serializer do
  subject { described_class.new(response) }

  let(:response) { build_stubbed(:verification_record_response) }
  let(:serialized_json) { subject.to_json }
  let(:parsed_json) { JSON.parse(serialized_json) }

  describe '#serializable_hash' do
    it 'includes claimant_id' do
      expect(subject.serializable_hash[:claimant_id]).to eq response.claimant_id
    end

    it 'includes delimiting_date' do
      expect(subject.serializable_hash[:delimiting_date]).to eq response.delimiting_date
    end

    it 'includes enrollment_verifications' do
      expect(subject.serializable_hash[:enrollment_verifications]).to eq response.enrollment_verifications
    end

    it 'includes verified_details' do
      expect(subject.serializable_hash[:verified_details]).to eq response.verified_details
    end

    it 'includes payment_on_hold' do
      expect(subject.serializable_hash[:payment_on_hold]).to eq response.payment_on_hold
    end
  end

  describe '#to_json' do
    it 'includes claimant_id' do
      expect(parsed_json['claimant_id']).to eq response.claimant_id
    end

    it 'includes delimiting_date' do
      expect(parsed_json['delimiting_date']).to eq response.delimiting_date
    end

    it 'includes enrollment_verifications' do
      expect(parsed_json['enrollment_verifications']).to eq response.enrollment_verifications
    end

    it 'includes verified_details' do
      expect(parsed_json['verified_details']).to eq response.verified_details
    end

    it 'includes payment_on_hold' do
      expect(parsed_json['payment_on_hold']).to eq response.payment_on_hold
    end

    it 'returns valid JSON' do
      expect { JSON.parse(serialized_json) }.not_to raise_error
    end
  end

  describe '#status' do
    it 'returns the response status' do
      expect(subject.status).to eq response.status
    end
  end
end

RSpec.describe Vye::VerifyClaimantSerializer, type: :serializer do
  subject { described_class.new(response) }

  let(:response) { build_stubbed(:verify_claimant_response) }
  let(:serialized_json) { subject.to_json }
  let(:parsed_json) { JSON.parse(serialized_json) }

  describe '#serializable_hash' do
    it 'includes claimant_id' do
      expect(subject.serializable_hash[:claimant_id]).to eq response.claimant_id
    end

    it 'includes delimiting_date' do
      expect(subject.serializable_hash[:delimiting_date]).to eq response.delimiting_date
    end

    it 'includes verified_details' do
      expect(subject.serializable_hash[:verified_details]).to eq response.verified_details
    end

    it 'includes payment_on_hold' do
      expect(subject.serializable_hash[:payment_on_hold]).to eq response.payment_on_hold
    end
  end

  describe '#to_json' do
    it 'includes claimant_id' do
      expect(parsed_json['claimant_id']).to eq response.claimant_id
    end

    it 'includes delimiting_date' do
      expect(parsed_json['delimiting_date']).to eq response.delimiting_date
    end

    it 'includes verified_details' do
      expect(parsed_json['verified_details']).to eq response.verified_details
    end

    it 'includes payment_on_hold' do
      expect(parsed_json['payment_on_hold']).to eq response.payment_on_hold
    end

    it 'returns valid JSON' do
      expect { JSON.parse(serialized_json) }.not_to raise_error
    end
  end

  describe '#status' do
    it 'returns the response status' do
      expect(subject.status).to eq response.status
    end
  end
end

# Shared examples for testing error responses
RSpec.shared_examples 'handles error responses' do |factory_name|
  subject { described_class.new(error_response) }

  let(:error_response) { build_stubbed(factory_name, status: 404) }

  it 'returns status from response' do
    expect(subject.status).to eq 404
  end

  it 'handles serialization gracefully' do
    expect { subject.serializable_hash }.not_to raise_error
  end
end

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Error handling' do
  describe Vye::ClaimantLookupSerializer do
    include_examples 'handles error responses', :claimant_lookup_response
  end

  describe Vye::ClaimantVerificationSerializer do
    include_examples 'handles error responses', :verification_record_response
  end

  describe Vye::VerifyClaimantSerializer do
    include_examples 'handles error responses', :verify_claimant_response
  end
end
# rubocop:enable RSpec/DescribeClass
# rubocop:enable RSpec/MultipleDescribes
