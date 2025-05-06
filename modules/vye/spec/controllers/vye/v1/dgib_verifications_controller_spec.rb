# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require 'vye/vye_serializer'

RSpec.describe Vye::V1::DgibVerificationsController, type: :controller do
  routes { Vye::Engine.routes }

  let!(:current_user) { create(:user, :accountable) }
  let(:claimant_id) { '1' }

  before do
    subject.instance_variable_set(:@_response, ActionDispatch::Response.new)
    sign_in_as(current_user)
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
    controller.instance_variable_set(:@current_user, current_user)

    # Mock the VyePolicy
    policy = instance_double(VyePolicy, access?: true)
    allow(VyePolicy).to receive(:new).and_return(policy)
    # Skip the verify_authorized check
    allow(controller).to receive(:verify_authorized).and_return(true)
    # Allow the authorize call to pass
    allow(controller).to receive(:authorize).with(:vye, :access?).and_return(true)
  end

  describe '#claimant_lookup' do
    let(:claimant_service_response) { create_claimant_response }
    let(:serializer) { Vye::ClaimantLookupSerializer.new(claimant_service_response) }

    before do
      allow_any_instance_of(Vye::DGIB::Service)
        .to receive(:claimant_lookup)
        .and_return(claimant_service_response)

      allow(Vye::ClaimantLookupSerializer)
        .to receive(:new)
        .with(claimant_service_response)
        .and_return(serializer)
    end

    context 'when the service returns a successful response' do
      it 'calls the claimant_lookup_service' do
        expect_any_instance_of(Vye::DGIB::Service).to receive(:claimant_lookup)
        post :claimant_lookup
      end

      it 'renders the serialized response with a 200 status' do
        expect(controller).to receive(:render).with(json: serializer.serializable_hash.to_json)
        post :claimant_lookup
      end
    end
  end

  def create_claimant_response
    response_struct = Struct.new(:body)
    response = response_struct.new({ 'claimant_id' => 1 })
    Vye::DGIB::ClaimantLookupResponse.new(200, response)
  end

  describe '#verify_claimant' do
    let(:verify_claimant_response) { create_verify_claimant_response }
    let(:serializer) { Vye::VerifyClaimantSerializer.new(verify_claimant_response) }
    let(:verified_period_begin_date) { '2024-11-01' }
    let(:verified_period_end_date) { '2024-11-30' }
    let(:verified_through_date) { '2023-11-30' }

    before do
      allow_any_instance_of(Vye::DGIB::Service)
        .to receive(:verify_claimant)
        .and_return(verify_claimant_response)

      allow(Vye::VerifyClaimantSerializer)
        .to receive(:new)
        .with(verify_claimant_response)
        .and_return(serializer)
    end

    context 'when the service returns a successful response' do
      it 'calls the verify_claimant_service' do
        expect_any_instance_of(Vye::DGIB::Service).to receive(:verify_claimant)

        post :verify_claimant, params: {
          claimant_id:,
          verified_period_begin_date:,
          verified_period_end_date:,
          verified_through_date:
        }
      end

      it 'renders the serialized response with a 200 status' do
        expect(controller).to receive(:render).with(json: serializer.serializable_hash.to_json)

        post :verify_claimant, params: {
          claimant_id:,
          verified_period_begin_date:,
          verified_period_end_date:,
          verified_through_date:
        }
      end
    end
  end

  def create_verify_claimant_response
    response_struct = Struct.new(:body)
    response = response_struct.new(
      {
        'claimant_id' => 1,
        'delimiting_date' => '2024-11-01',
        'verified_details' => {
          'benefit_type' => 'CH33',
          'verification_through_date' => '2024-11-01',
          'verification_method' => 'Initial'
        },
        'payment_on_hold' => true
      }
    )

    Vye::DGIB::VerifyClaimantResponse.new(200, response)
  end
end
