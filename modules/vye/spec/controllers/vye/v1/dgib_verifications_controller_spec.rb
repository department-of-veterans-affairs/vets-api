# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe VYE::V1::DgibVerificationsController, type: :controller do
  let!(:current_user) { create(:user, :accountable) }
  let(:claimant_id) { '1' }

  before do
    # Nothing with the routing seemed to work but subject.claimant_lookup works. However
    # it gives this error:
    # Module::DelegationError:
    #  ActionController::Metal#media_type delegated to @_response.media_type, but @_response is nil:
    # #<V1::DgibVerificationsController:0x0000000003b150>
    # What makes this work is to set the @_response instance variable.
    subject.instance_variable_set(:@_response, ActionDispatch::Response.new)

    sign_in_as(current_user)
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
  end

  describe '#claimant_lookup' do
    let(:claimant_service_response) { create_claimant_response }
    let(:serializer) { Vye::ClaimantLookupSerializer.new(claimant_service_response) }

    before do
      allow_any_instance_of(VyePolicy).to receive(:access?).and_return(true)
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
        # You have to do this or the test will fail.
        # Something buried in pundit is preventing it from working without it
        # Consequently, no separate test for pundit
        expect(controller).to receive(:authorize).with(@current_user, policy_class: UserInfoPolicy).and_return(true)

        subject.claimant_lookup
      end

      it 'renders the serialized response with a 200 status' do
        # You have to do this or the test will fail.
        # Something buried in pundit is preventing it from working without it
        # Consequently, no separate test for pundit
        expect(controller).to receive(:authorize).with(@current_user, policy_class: UserInfoPolicy).and_return(true)

        # Chatgpt says do this, but it does not work:
        # expect(controller).to receive(:render).with(json: serializer.new(claimant_service_response).to_json)
        # What works is this
        expect(controller).to receive(:render).with(json: serializer.serializable_hash.to_json)

        subject.claimant_lookup
      end
    end
  end

  # The remaining tests will be done via requests. There were too many issues with RSpec trying to
  # make them work as controller tests, mostly having to do with post requests.

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
    let(:verfied_through_date) { '2023-11-30' }

    before do
      allow_any_instance_of(VyePolicy).to receive(:access?).and_return(true)
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

        # You have to do this or the test will fail.
        # Something buried in pundit is preventing it from working without it
        # Consequently, no separate test for pundit
        expect(controller).to receive(:authorize).with(@current_user, policy_class: UserInfoPolicy).and_return(true)

        subject.params =
          { claimant_id:, verified_period_begin_date:, verified_period_end_date:, verfied_through_date: }

        subject.verify_claimant
      end

      it 'renders the serialized response with a 200 status' do
        # You have to do this or the test will fail.
        # Something buried in pundit is preventing it from working without it
        # Consequently, no separate test for pundit
        expect(controller).to receive(:authorize).with(@current_user, policy_class: UserInfoPolicy).and_return(true)

        # Chatgpt says do this, but it does not work:
        # expect(controller).to receive(:render).with(json: serializer.new(claimant_service_response).to_json)
        # What works is this
        expect(controller).to receive(:render).with(json: serializer.serializable_hash.to_json)

        subject.params =
          { claimant_id:, verified_period_begin_date:, verified_period_end_date:, verfied_through_date: }

        subject.verify_claimant
        expect(serializer.status).to eq(200)
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
