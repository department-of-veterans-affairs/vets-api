# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::V1::Forms::DisabilityCompensationController, type: :controller do
  let(:token) do
    OpenStruct.new(
      payload: OpenStruct.new(
        cid: '75648392047777685'
      )
    )
  end
  let(:veteran) do
    OpenStruct.new(
      middle_name: 'William',
      mpi: OpenStruct.new(
        icn: '1012861229V078999'
      )
    )
  end
  let(:claim) { create(:auto_established_claim, form_data: JSON.parse(claim_data)) }
  let(:claim_data) do
    temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json').read
    temp = JSON.parse(temp)
    temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled
    temp['data']['attributes']['claimDate'] = claim_date
    temp['data']['attributes']['applicationExpirationDate'] = (Time.zone.today + 1.day).to_s

    temp.to_json
  end
  let(:auto_cest_pdf_generation_disabled) { false }
  let(:claim_date) { (Time.zone.today - 1.day).to_s }
  let(:middle_initial) { veteran.middle_name[0] }

  before do
    allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v1_enable_FES).and_return(true)
    # mock for form_attributes method calls
    subject.instance_variable_set(:@json_body, JSON.parse(claim_data))
    # mock passing custom validations - extend the module onto the subject
    allow_any_instance_of(
      ClaimsApi::RevisedDisabilityCompensationValidations
    ).to receive(:validate_form_526_submission_values!).and_return(nil)
    # mock valid veteran identification
    allow_any_instance_of(described_class).to receive(:validate_veteran_identifiers).with(anything).and_return(nil)
  end

  describe '#format_526_errors' do
    it 'formats errors correctly' do
      error = [
        {
          key: 'header.va_eauth_birlsfilenumber.Invalid',
          severity: 'ERROR',
          text: 'Size must be between 8 and 9'
        }
      ]

      formatted_error = subject.send(:format_526_errors, error)

      expect(formatted_error).to contain_exactly(
        { status: 422, detail: "#{error[0][:key]}, #{error[0][:text]}", source: error[0][:key] }
      )
    end
  end

  describe '#submit_form_526' do
    context 'using the PDF Generator' do
      before do
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:create).with(any_args).and_return(claim)
        allow(ClaimsApi::V1::DisabilityCompensationPdfGenerator).to receive(:perform_async)
        allow(ClaimsApi::AutoEstablishedClaimSerializer).to receive(:new).with(claim).and_return(double(as_json: {}))
        allow_any_instance_of(
          described_class
        ).to receive_messages(validate_json_schema: nil, validate_initial_claim: nil,
                              target_veteran: veteran, token:, auth_headers: {}, render: nil)
      end

      it 'calls the PDF Generator Sidekiq job with the expected params when the flipper is enabled' do
        subject.send(:submit_form_526) # rubocop:disable Naming/VariableNumber

        expect(ClaimsApi::V1::DisabilityCompensationPdfGenerator).to have_received(:perform_async)
          .with(claim.id, middle_initial)
      end
    end
  end

  describe '#validate_form_526' do
    context 'using the FES validation' do
      let(:fes_service) { ClaimsApi::FesService::Base.new }

      before do
        allow(ClaimsApi::FesService::Base).to receive(:new).and_return(fes_service)
        allow(fes_service).to receive(:validate).and_return(true)
        allow_any_instance_of(
          described_class
        ).to receive_messages(add_deprecation_headers_to_response: nil, validate_initial_claim: nil,
                              auth_headers: claim.auth_headers, render: nil)
      end

      it 'when the flipper is enabled' do
        subject.send(:validate_form_526) # rubocop:disable Naming/VariableNumber

        expect(fes_service).to have_received(:validate)
      end
    end
  end

  describe '#upload_form_526' do
    def upload_form_526!
      subject.send(:upload_form_526) # rubocop:disable Naming/VariableNumber
    end

    let(:pending_claim) do
      create(
        :auto_established_claim,
        form_data: { 'autoCestPDFGenerationDisabled' => auto_cest_pdf_generation_disabled }
      )
    end
    let(:attachment) do
      Rack::Test::UploadedFile.new(
        Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'extras.pdf'),
        'application/pdf'
      )
    end
    let(:upload_form_526_params) do
      ActionController::Parameters.new(
        'id' => pending_claim&.id || '123',
        'attachment' => attachment
      )
    end

    # common error messages
    let(:field_required_error) do
      'Claim submission requires that the "autoCestPDFGenerationDisabled" field ' \
        'must be set to "true" in order to allow a 526 PDF to be uploaded'
    end

    let(:not_found_error) { 'Resource not found' }

    before do
      allow(controller).to receive(:claims_v1_logging)
      allow(controller).to receive(:render)
      allow(controller).to receive(:params).and_return(upload_form_526_params)
    end

    describe 'with FES service enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v1_enable_FES).and_return(true)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:pending?).and_return(pending_claim)
      end

      context 'when autoCestPDFGenerationDisabled is false on the form' do
        let(:auto_cest_pdf_generation_disabled) { false }

        it 'throws an UnprocessableEntity error with the expected detail message' do
          expect { upload_form_526! }
            .to raise_error(Common::Exceptions::UnprocessableEntity) { |error|
              expect(error.errors.first.detail.squish).to eq(field_required_error)
            }
        end
      end

      context 'when autoCestPDFGenerationDisabled is true on the form' do
        let(:auto_cest_pdf_generation_disabled) { true }

        before do
          allow(ClaimsApi::V1::Form526EstablishmentUpload).to receive(:perform_async).with(pending_claim&.id)
        end

        it 'calls the FES claim establishment and upload method' do
          upload_form_526!
          expect(ClaimsApi::V1::Form526EstablishmentUpload).to have_received(
            :perform_async
          ).with(pending_claim&.id).once
        end

        it 'does not call the ClaimEstablisher and ClaimUploader jobs' do
          allow(ClaimsApi::ClaimEstablisher).to receive(:perform_async)
          allow(ClaimsApi::ClaimUploader).to receive(:perform_async)
          upload_form_526!
          expect(ClaimsApi::ClaimEstablisher).not_to have_received(:perform_async)
          expect(ClaimsApi::ClaimUploader).not_to have_received(:perform_async)
        end

        it 'renders the serialized pending claim' do
          expect(controller).to receive(:render) do |args|
            expect(args[:json]).to be_a(ClaimsApi::AutoEstablishedClaimSerializer)
            expect(args[:json].serializable_hash[:data][:id]).to eq(pending_claim.id)
          end

          upload_form_526!
        end
      end

      context 'when autoCestPDFGenerationDisabled is nil on the form' do
        let(:auto_cest_pdf_generation_disabled) { nil }

        it "returns a 'resource not found' error" do
          expect { upload_form_526! }
            .to raise_error(Common::Exceptions::UnprocessableEntity) { |error|
              expect(error.errors.first.detail.squish).to eq(field_required_error)
            }
        end
      end

      context 'when autoCestPDFGenerationDisabled is not present on the form' do
        let(:pending_claim) { create(:auto_established_claim, form_data: {}) }

        it "returns a 'resource not found' error" do
          expect { upload_form_526! }
            .to raise_error(Common::Exceptions::UnprocessableEntity) { |error|
              expect(error.errors.first.detail.squish).to eq(field_required_error)
            }
        end
      end

      context 'when the pending claim cannot be found' do
        before do
          allow(ClaimsApi::AutoEstablishedClaim).to receive(:pending?).and_return(nil)
        end

        it "returns a 'resource not found' error" do
          expect { upload_form_526! }
            .to raise_error(Common::Exceptions::ResourceNotFound) { |error|
              expect(error.errors.first.detail.squish).to eq(not_found_error)
            }
        end
      end
    end

    describe 'with the FES service disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v1_enable_FES).and_return(false)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:pending?).and_return(pending_claim)
      end

      context 'when autoCestPDFGenerationDisabled is false on the form' do
        let(:auto_cest_pdf_generation_disabled) { false }

        it 'throws an UnprocessableEntity error with the expected detail message' do
          expect { upload_form_526! }
            .to raise_error(Common::Exceptions::UnprocessableEntity) { |error|
              expect(error.errors.first.detail.squish).to eq(field_required_error)
            }
        end
      end

      context 'when autoCestPDFGenerationDisabled is true on the form' do
        let(:auto_cest_pdf_generation_disabled) { true }

        before do
          allow(ClaimsApi::ClaimEstablisher).to receive(:perform_async)
          allow(ClaimsApi::ClaimUploader).to receive(:perform_async)
        end

        it 'calls the claim establishment and upload method' do
          upload_form_526!
          expect(ClaimsApi::ClaimEstablisher).to have_received(
            :perform_async
          ).with(pending_claim.id).once
          expect(ClaimsApi::ClaimUploader).to have_received(
            :perform_async
          ).with(pending_claim.id, 'claim').once
        end

        it 'does not call the FES Form526EstablishmentUpload job' do
          allow(ClaimsApi::V1::Form526EstablishmentUpload).to receive(:perform_async)
          upload_form_526!
          expect(ClaimsApi::V1::Form526EstablishmentUpload).not_to have_received(:perform_async)
        end

        it 'renders the serialized pending claim' do
          expect(controller).to receive(:render) do |args|
            expect(args[:json]).to be_a(ClaimsApi::AutoEstablishedClaimSerializer)
            expect(args[:json].serializable_hash[:data][:id]).to eq(pending_claim.id)
          end

          upload_form_526!
        end
      end

      context 'when autoCestPDFGenerationDisabled is nil on the form' do
        let(:auto_cest_pdf_generation_disabled) { nil }

        it "returns a 'resource not found' error" do
          expect { upload_form_526! }
            .to raise_error(Common::Exceptions::UnprocessableEntity) { |error|
              expect(error.errors.first.detail.squish).to eq(field_required_error)
            }
        end
      end

      context 'when autoCestPDFGenerationDisabled is not present on the form' do
        let(:pending_claim) { create(:auto_established_claim, form_data: {}) }

        it "returns a 'resource not found' error" do
          expect { upload_form_526! }
            .to raise_error(Common::Exceptions::UnprocessableEntity) { |error|
              expect(error.errors.first.detail.squish).to eq(field_required_error)
            }
        end
      end

      context 'when the pending claim cannot be found' do
        before do
          allow(ClaimsApi::AutoEstablishedClaim).to receive(:pending?).and_return(nil)
        end

        it "returns a 'resource not found' error" do
          expect { upload_form_526! }
            .to raise_error(Common::Exceptions::ResourceNotFound) { |error|
              expect(error.errors.first.detail.squish).to eq(not_found_error)
            }
        end
      end
    end
  end
end
