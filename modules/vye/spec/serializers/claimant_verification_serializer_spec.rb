# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'
require 'vye/vye_serializer'

RSpec.describe Vye::ClaimantVerificationSerializer, type: :serializer do
  let(:json_body) { 'modules/vye/spec/fixtures/claimant_response.json' }
  let(:claimant_verfication) { File.read(json_body) }
  let(:data) { JSON.parse(claimant_verfication) }

  it 'includes :claimant_id' do
    expect(data['claimant_id']).to eq claimant_verfication['claimant_id']
  end

  it 'includes :delimiting_date' do
    expect(data['delimiting_date']).to eq claimant_verfication['delimiting_date']
  end

  it 'includes :enrollment_verifications' do
    expect(data['enrollment_verifications']).to eq claimant_verfication['enrollment_verifications']
  end

  it 'includes :verified_details' do
    expect(data['verified_details']).to eq claimant_verfication['verified_details']
  end

  it 'includes :payment_on_hold' do
    expect(data['payment_on_hold']).to eq claimant_verfication['payment_on_hold']
  end
end
