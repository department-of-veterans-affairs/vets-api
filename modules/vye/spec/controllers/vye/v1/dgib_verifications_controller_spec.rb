# frozen_string_literal: true

# NOTE: Only going to test the failure paths for one action. If the tests pass for one,
# they pass for all.

require 'rails_helper'
require 'vye/vye_serializer'
require_relative '../../../support/vye/shared_examples/controller_error_responses'

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

    # Skip the verify_authorized check
    allow(controller).to receive(:verify_authorized).and_return(true)
    # Allow the authorize call to pass
    allow(controller).to receive(:authorize).with(:vye, :access?).and_return(true)
  end

  describe '#verification_record' do
    let(:verification_record_response) { build_stubbed(:verification_record_response, status: 200) }
    let(:serializer) { Vye::ClaimantVerificationSerializer.new(verification_record_response) }

    before do
      allow_any_instance_of(Vye::DGIB::Service)
        .to receive(:get_verification_record)
        .and_return(verification_record_response)
    end

    context 'when the service returns a successful response' do
      it 'calls the verification_record_service' do
        expect_any_instance_of(Vye::DGIB::Service).to receive(:get_verification_record)

        post :verification_record, params: { claimant_id: }
      end

      it 'renders the serialized response with a 200 status' do
        post :verification_record, params: { claimant_id: }
        expect(controller).to receive(:render).with(json: serializer.serializable_hash.to_json)

        post :verification_record, params: { claimant_id: }
      end
    end

    context 'when the service fails for one reason or another' do
      context 'when the service returns 204 (no content)' do
        include_examples 'handles error response', :no_content, 204, :no_content
      end

      context 'when the service returns 403 (forbidden)' do
        include_examples 'handles error response', :forbidden, 403, :forbidden
      end

      context 'when the service returns 404 (not found)' do
        include_examples 'handles error response', :not_found, 404, :not_found
      end

      context 'when the service returns 422 (unprocessable entity)' do
        include_examples 'handles error response', :unprocessable_entity, 422, :unprocessable_entity
      end

      context 'when the service is unavailable' do
        include_examples 'handles error response', :service_unavailable, nil, :service_unavailable
        include_examples 'logs error response', /Nil response status/
      end

      context 'when the service returns 500 (server error)' do
        include_examples 'handles error response', :server_error, 500, :internal_server_error
        include_examples 'logs error response', /Unexpected response status: 500/
      end
    end
  end

  describe '#verify_claimant' do
    let(:verify_claimant_response) { build_stubbed(:verify_claimant_response, status: 200) }
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

  describe '#claimant_status' do
    let(:claimant_status_response) { build_stubbed(:claimant_status_response, status: 200) }
    let(:serializer) { Vye::VerifyClaimantSerializer.new(claimant_status_response) }

    before do
      allow_any_instance_of(Vye::DGIB::Service)
        .to receive(:get_claimant_status)
        .and_return(claimant_status_response)

      allow(Vye::VerifyClaimantSerializer)
        .to receive(:new)
        .with(claimant_status_response)
        .and_return(serializer)
    end

    context 'when the service returns a successful response' do
      it 'calls the claimant_status_service' do
        expect_any_instance_of(Vye::DGIB::Service).to receive(:get_claimant_status)

        post :claimant_status, params: { claimant_id: }
      end

      it 'renders the serialized response with a 200 status' do
        expect(controller).to receive(:render).with(json: serializer.serializable_hash.to_json)

        post :claimant_status, params: { claimant_id: }
      end
    end
  end

  describe '#claimant_lookup' do
    let(:claimant_service_response) { build_stubbed(:claimant_lookup_response) }
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
end
