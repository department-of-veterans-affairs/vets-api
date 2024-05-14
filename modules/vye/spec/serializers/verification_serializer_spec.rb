# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::VerificationSerializer, type: :serializer do
  let(:resource) { build(:vye_verification) } # Assuming you have a factory for verification
  let(:serializer) { described_class.new(resource) }
  let(:serialization) { ActiveModelSerializers::Adapter.create(serializer, {}) }

  it 'includes the expected attributes' do
    expect do
      serialization.as_json
    end.not_to raise_error
  end
end
