# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept, type: :service do
  subject(:service_call) { described_class.new(poa_request, creator).call }

  let!(:creator)     { create(:representative_user) }
  let!(:poa_request) { create(:power_of_attorney_request) }

  let(:monitor) { instance_spy('Monitoring') }

  before do
    stub_const('Monitoring', Class.new) unless Object.const_defined?('Monitoring')
    allow(Monitoring).to receive(:new).and_return(monitor)

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
      monitor.track_duration('ar.poa.submission.duration', from: poa_request.created_at)
      monitor.track_duration('ar.poa.submission.enqueue_failed.duration', from: poa_request.created_at)
    end
  end

  def stub_benefits_claims_submit2122_returning(id:)
    svc = instance_double('BenefitsClaims::Service')
    allow(BenefitsClaims::Service).to receive(:new)
      .with(poa_request.claimant.icn)
      .and_return(svc)
    allow(svc).to receive(:submit2122).and_return(
      instance_double('Response', body: { 'data' => { 'id' => id } })
    )
    svc
  end

  describe 'happy path' do
    it 'creates acceptance, submits to BenefitsClaims, enqueues job, tracks metrics, and returns the submission record' do
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

        # Acceptance decision creation is invoked (stubbed)
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision)
          .to have_received(:create_acceptance!)
      end.to change(AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission, :count).by(1)
    end

    it 'builds the correct payload for submit2122' do
      svc = stub_benefits_claims_submit2122_returning(id: 'svc-xyz')
      allow(AccreditedRepresentativePortal::PowerOfAttorneyFormSubmissionJob)
        .to receive(:perform_async)

      described_class.new(poa_request, creator).call

      expect(svc).to have_received(:submit2122) do |payload|
        expect(payload).to include(:veteran, :serviceOrganization, :recordConsent, :consentLimits, :consentAddressChange)

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
      s = instance_double('BenefitsClaims::Service')
      allow(BenefitsClaims::Service).to receive(:new).and_return(s)
      s
    end

    it 'wraps Common::Exceptions::ResourceNotFound as Accept::Error with :not_found' do
      # allocate an instance and supply the needed methods without verified-doubles issues
      not_found = Common::Exceptions::ResourceNotFound.allocate
      not_found.define_singleton_method(:detail)  { 'not found' }
      not_found.define_singleton_method(:message) { 'not found' }

      allow(svc).to receive(:submit2122).and_raise(not_found)

      expect { service_call }
        .to raise_error(described_class::Error) { |e|
          expect(e.status).to eq(:not_found)
          expect(e.message).to eq('not found')
        }
    end

    it 'wraps ActiveRecord::RecordInvalid as Accept::Error with :bad_request' do
      invalid = ActiveRecord::RecordInvalid.allocate
      invalid.define_singleton_method(:message) { 'invalid' }

      allow(svc).to receive(:submit2122).and_raise(invalid)

      expect { service_call }
        .to raise_error(described_class::Error) { |e|
          expect(e.status).to eq(:bad_request)
          expect(e.message).to eq('invalid')
        }
    end

    it 'maps Faraday::TimeoutError to Accept::Error with :gateway_timeout' do
      allow(svc).to receive(:submit2122).and_raise(Faraday::TimeoutError.new('timeout'))

      expect { service_call }
        .to raise_error(described_class::Error) { |e|
          expect(e.status).to eq(:gateway_timeout)
          expect(e.message).to eq('timeout')
        }
    end

    it 'handles configured FATAL errors: creates failed submission and raises Accept::Error(:not_found)' do
      class SyntheticFatal < StandardError
        def detail = 'bad request'
      end
      stub_const("#{described_class.name}::FATAL_ERROR_TYPES", [SyntheticFatal])

      allow(svc).to receive(:submit2122).and_raise(SyntheticFatal.new('bad request'))

      expect {
        service_call
      }.to raise_error(described_class::Error) { |e|
        expect(e.status).to eq(:not_found)
        expect(e.message).to eq('bad request')
      }

      failed = AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission.order(:created_at).last
      expect(failed.status).to eq('enqueue_failed')
      expect(failed.error_message).to eq('bad request')

      expect(monitor).to have_received(:track_duration).with('ar.poa.submission.duration', from: poa_request.created_at)
      expect(monitor).to have_received(:track_duration).with('ar.poa.submission.enqueue_failed.duration', from: poa_request.created_at)
    end

    it 'handles configured TRANSIENT errors: raises Accept::Error(:gateway_timeout)' do
      class SyntheticTransient < StandardError; end
      stub_const("#{described_class.name}::TRANSIENT_ERROR_TYPES", [SyntheticTransient])

      allow(svc).to receive(:submit2122).and_raise(SyntheticTransient.new('please retry'))

      expect { service_call }
        .to raise_error(described_class::Error) { |e|
          expect(e.status).to eq(:gateway_timeout)
          expect(e.message).to eq('please retry')
        }
    end

    it 'handles unexpected errors: logs, creates failed submission, and re-raises' do
      allow(Rails.logger).to receive(:error)
      allow(svc).to receive(:submit2122).and_raise(RuntimeError, 'boom')

      expect {
        service_call
      }.to raise_error(RuntimeError, 'boom')

      failed = AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission.order(:created_at).last
      expect(failed.status).to eq('enqueue_failed')
      expect(failed.error_message).to eq('boom')

      expect(Rails.logger).to have_received(:error).with(/Unexpected error in Accept#call: RuntimeError - boom/)
      expect(Rails.logger).to have_received(:error).at_least(:twice)
    end
  end
end
