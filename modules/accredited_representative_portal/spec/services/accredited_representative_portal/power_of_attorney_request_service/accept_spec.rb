# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept, type: :service do
  subject(:service_call) { described_class.new(poa_request, creator.uuid, memberships).call }

  let!(:creator)     { create(:representative_user) }
  let!(:poa_request) { create(:power_of_attorney_request) }

  let(:monitor) { instance_spy(AccreditedRepresentativePortal::Monitoring, track_duration: nil, track_count: nil, trace: nil) }

  let(:memberships) do
    memo =
      AccreditedRepresentativePortal::PowerOfAttorneyHolderMemberships.new(
        icn: '1234', emails: []
      )

    allow(memo).to(
      receive(:all).and_return(
        [
          AccreditedRepresentativePortal::PowerOfAttorneyHolderMemberships::Membership.new(
            registration_number: 'REG-777',
            power_of_attorney_holder:
              AccreditedRepresentativePortal::PowerOfAttorneyHolder.new(
                poa_code: poa_request.power_of_attorney_holder_poa_code,
                type: poa_request.power_of_attorney_holder_type,
                can_accept_digital_poa_requests: false,
                name: 'Org Name'
              )
          )
        ]
      )
    )

    memo
  end

  before do
    monitoring_class = class_double(AccreditedRepresentativePortal::Monitoring).as_stubbed_const
    allow(monitoring_class).to receive(:new).and_return(monitor)

    allow(Rails.logger).to receive(:error)

    creator.define_singleton_method(:get_registration_number) { |_holder_type| 'REG-777' }

    allow(AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision)
      .to receive(:create_acceptance!)
      .and_return(double('decision'))

    allow(poa_request.power_of_attorney_form).to receive(:parsed_data).and_return(
      {
        'veteran' => {
          'email' => 'vet@example.com',
          'serviceNumber' => 'SVC123',
          'insuranceNumber' => 'INS999',
          'phone' => '202-555-0123 77',
          'address' => {
            'addressLine1' => '123 Main St',
            'addressLine2' => 'Apt 4',
            'city' => 'Springfield',
            'stateCode' => 'VA',
            'country' => 'US',
            'zipCode' => '12345',
            'zipCodeSuffix' => '6789'
          }
        },
        'authorizations' => {
          'recordDisclosureLimitations' => nil,
          'addressChange' => true
        }
      }
    )

    allow_any_instance_of(described_class).to receive(:create_error_form_submission) do |_, message, response_body|
      AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission.create(
        power_of_attorney_request: poa_request,
        status: :enqueue_failed,
        status_updated_at: DateTime.current,
        service_response: response_body.to_json,
        error_message: message
      )

      monitor.track_duration('ar.poa.submission.enqueue_failed.duration', from: poa_request.created_at)
    end
  end

  def stub_benefits_claims_submit2122_returning(id:)
    svc = instance_double(BenefitsClaims::Service)
    allow(BenefitsClaims::Service).to receive(:new)
      .with(poa_request.claimant.icn)
      .and_return(svc)
    allow(svc).to receive(:submit2122).and_return(
      OpenStruct.new(body: { 'data' => { 'id' => id } })
    )
    svc
  end

  describe 'happy path' do
    it 'creates acceptance, submits, enqueues job, tracks metrics, and returns the submission' do
      stub_benefits_claims_submit2122_returning(id: 'svc-123')
      allow(AccreditedRepresentativePortal::PowerOfAttorneyFormSubmissionJob)
        .to receive(:perform_async)

      expect do
        result = service_call

        expect(result).to be_a(AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission)
        expect(result.status).to eq('enqueue_succeeded')
        expect(result.service_id).to eq('svc-123')
        expect(JSON.parse(result.service_response)).to eq({ 'data' => { 'id' => 'svc-123' } })

        expect(AccreditedRepresentativePortal::PowerOfAttorneyFormSubmissionJob)
          .to have_received(:perform_async).with(result.id)

        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision)
          .to have_received(:create_acceptance!)
      end.to change(AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission, :count).by(1)
    end

    it 'builds the correct payload for submit2122' do
      svc = stub_benefits_claims_submit2122_returning(id: 'svc-xyz')
      allow(AccreditedRepresentativePortal::PowerOfAttorneyFormSubmissionJob)
        .to receive(:perform_async)

      described_class.new(poa_request, creator.uuid, memberships).call

      expect(svc).to have_received(:submit2122) do |payload|
        expect(payload).to include(
          :veteran, :serviceOrganization, :recordConsent, :consentLimits, :consentAddressChange
        )

        expect(payload[:serviceOrganization]).to eq(
          poaCode: poa_request.power_of_attorney_holder_poa_code,
          registrationNumber: 'REG-777'
        )

        expect(payload[:veteran][:email]).to eq('vet@example.com')
        expect(payload[:veteran][:serviceNumber]).to eq('SVC123')
        expect(payload[:veteran][:insuranceNumber]).to eq('INS999')
        expect(payload[:veteran][:phone]).to eq(
          areaCode: '202',
          phoneNumber: '5550123',
          phoneNumberExt: '77'
        )
        expect(payload[:veteran][:address]).to include(
          addressLine1: '123 Main St',
          addressLine2: 'Apt 4',
          city: 'Springfield',
          stateCode: 'VA',
          countryCode: 'US',
          zipCode: '12345',
          zipCodeSuffix: '6789'
        )

        expect(payload[:recordConsent]).to be(true)
        expect(payload[:consentLimits]).to be_nil
        expect(payload[:consentAddressChange]).to be(true)
      end
    end
  end

  describe 'error handling' do
    let(:svc) do
      s = instance_double(BenefitsClaims::Service)
      allow(BenefitsClaims::Service).to receive(:new).and_return(s)
      s
    end

    it 'wraps Common::Exceptions::ResourceNotFound as Accept::Error with :not_found' do
      not_found = Common::Exceptions::ResourceNotFound.allocate
      not_found.define_singleton_method(:detail)  { 'not found' }
      not_found.define_singleton_method(:message) { 'not found' }

      allow(svc).to receive(:submit2122).and_raise(not_found)

      expect do
        service_call
      end.to raise_error(described_class::Error) { |e|
        expect(e.status).to eq(:not_found)
        expect(e.message).to eq('not found')
      }
    end

    it 'wraps ActiveRecord::RecordInvalid as Accept::Error with :bad_request' do
      invalid = ActiveRecord::RecordInvalid.allocate
      invalid.define_singleton_method(:message) { 'invalid' }

      allow(svc).to receive(:submit2122).and_raise(invalid)

      expect do
        service_call
      end.to raise_error(described_class::Error) { |e|
        expect(e.status).to eq(:bad_request)
        expect(e.message).to eq('invalid')
      }
    end

    it 'maps Faraday::TimeoutError to Accept::Error with :gateway_timeout' do
      allow(svc).to receive(:submit2122).and_raise(Faraday::TimeoutError.new('timeout'))

      expect do
        service_call
      end.to raise_error(described_class::Error) { |e|
        expect(e.status).to eq(:gateway_timeout)
        expect(e.message).to eq('timeout')
      }
    end

    it 'handles configured FATAL errors: creates failed submission and raises Accept::Error(:not_found)' do
      fatal_klass = Class.new(StandardError) do
        def detail = 'bad request'
      end
      stub_const("#{described_class.name}::FATAL_ERROR_TYPES", [fatal_klass])

      allow(svc).to receive(:submit2122).and_raise(fatal_klass.new('bad request'))

      expect do
        service_call
      end.to raise_error(described_class::Error) { |e|
        expect(e.status).to eq(:not_found)
        expect(e.message).to eq('bad request')
      }

      failed = AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission.order(:created_at).last
      expect(failed.status).to eq('enqueue_failed')
      expect(failed.error_message).to eq('bad request')

      expect(monitor).to have_received(:track_duration)
        .with('ar.poa.submission.enqueue_failed.duration', from: poa_request.created_at)
      expect(monitor).to have_received(:track_count).with(
        'ar.poa.submission.enqueue_failed.count',
        tags: array_including("error_class:#{fatal_klass.name}")
      )

      expect(Rails.logger).to have_received(:error).with(
        include(
          '[AR::POA] enqueue_failed',
          "poa_request_id=#{poa_request.id}",
          "poa_code=#{poa_request.power_of_attorney_holder_poa_code}",
          "error_class=#{fatal_klass.name}",
          'message=bad request'
        )
      )
    end

    it 'handles configured TRANSIENT errors: raises Accept::Error(:gateway_timeout)' do
      transient_klass = Class.new(StandardError)
      stub_const("#{described_class.name}::TRANSIENT_ERROR_TYPES", [transient_klass])

      allow(svc).to receive(:submit2122).and_raise(transient_klass.new('please retry'))

      expect do
        service_call
      end.to raise_error(described_class::Error) { |e|
        expect(e.status).to eq(:gateway_timeout)
        expect(e.message).to eq('please retry')
      }
    end

    it 'handles unexpected errors: logs, creates failed submission, and re-raises' do
      allow(Rails.logger).to receive(:error)
      allow(svc).to receive(:submit2122).and_raise(RuntimeError, 'boom')

      expect do
        service_call
      end.to raise_error(RuntimeError, 'boom')

      failed = AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission.order(:created_at).last
      expect(failed.status).to eq('enqueue_failed')
      expect(failed.error_message).to eq('boom')

      expect(Rails.logger).to have_received(:error)
        .with(/Unexpected error in Accept#call: RuntimeError - boom/)
      expect(Rails.logger).to have_received(:error).at_least(:twice)
    end
  end

  describe '#create_error_form_submission' do
    before do
      allow_any_instance_of(described_class)
        .to receive(:create_error_form_submission)
        .and_call_original
    end

    it 'stores string response bodies as-is' do
      instance = described_class.new(poa_request, creator.uuid, memberships)

      expect do
        instance.send(:create_error_form_submission, 'boom', 'raw-string-body')
      end.to change(AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission, :count).by(1)

      failed = AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission.order(:created_at).last
      expect(failed.status).to eq('enqueue_failed')
      expect(failed.error_message).to eq('boom')
      expect(failed.service_response).to eq('raw-string-body')
    end

    it 'serializes non-string response bodies to JSON' do
      instance = described_class.new(poa_request, creator.uuid, memberships)
      body = { 'foo' => 'bar', 'baz' => [1, 2, 3] }

      expect do
        instance.send(:create_error_form_submission, 'oops', body)
      end.to change(AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission, :count).by(1)

      failed = AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission.order(:created_at).last
      expect(failed.status).to eq('enqueue_failed')
      expect(failed.error_message).to eq('oops')
      expect(failed.service_response).to eq(body.to_json)
    end
  end
end
