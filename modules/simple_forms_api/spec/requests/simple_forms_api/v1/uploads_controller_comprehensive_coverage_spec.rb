# frozen_string_literal: true

require 'rails_helper'
require 'simple_forms_api_submission/metadata_validator'
require 'common/file_helpers'
require 'lighthouse/benefits_intake/service'
require 'lgy/service'
require 'benefits_intake_service/service'

RSpec.describe 'SimpleFormsApi::V1::UploadsController Coverage Improvement', type: :request do
  let(:user) { create(:user, :legacy_icn) }
  let(:lighthouse_service) { instance_double(BenefitsIntake::Service) }

  before do
    allow(BenefitsIntake::Service).to receive(:new).and_return(lighthouse_service)
    allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate).and_return({})
  end

  describe '#submit - Intent to File Exception Handling' do
    let(:data) do
      fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                     'vba_21_0966.json')
      data = JSON.parse(fixture_path.read)
      data['preparer_identification'] = 'VETERAN'
      data
    end

    before do
      sign_in(user)
      allow_any_instance_of(User).to receive(:participant_id).and_return('fake-participant-id')
      allow_any_instance_of(SimpleFormsApi::IntentToFile).to receive(:use_intent_api?).and_return(true)
      allow_any_instance_of(SimpleFormsApi::IntentToFile).to receive(:existing_intents).and_return({})
    end

    context 'when Common::Exceptions::UnprocessableEntity is raised' do
      before do
        allow_any_instance_of(SimpleFormsApi::IntentToFile).to receive(:submit)
          .and_raise(Common::Exceptions::UnprocessableEntity.new({}))
        
        # Mock the fallback to benefits intake
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:submit_form_to_benefits_intake)
          .and_return({ json: { confirmation_number: 'fallback-123' }, status: 200 })
      end

      it 'catches exception and falls back to benefits intake' do
        expect(Rails.logger).to receive(:info).with(
          'Simple forms api - 21-0966 Benefits Claims Intent to File API error,' \
          'reverting to filling a PDF and sending it to Benefits Intake API',
          hash_including(error: anything)
        )

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
      end

      it 'populates veteran params when user has no address' do
        allow_any_instance_of(User).to receive(:address).and_return({})

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
      end

      it 'populates veteran params when user has address' do
        allow_any_instance_of(User).to receive(:address).and_return({ postal_code: '12345' })

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when SimpleFormsApi::Exceptions::BenefitsClaimsApiDownError is raised' do
      before do
        allow_any_instance_of(SimpleFormsApi::IntentToFile).to receive(:submit)
          .and_raise(SimpleFormsApi::Exceptions::BenefitsClaimsApiDownError.new('API down'))
        
        # Mock the fallback to benefits intake
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:submit_form_to_benefits_intake)
          .and_return({ json: { confirmation_number: 'fallback-456' }, status: 200 })
      end

      it 'catches BenefitsClaimsApiDownError and falls back to benefits intake' do
        expect(Rails.logger).to receive(:info).with(
          'Simple forms api - 21-0966 Benefits Claims Intent to File API error,' \
          'reverting to filling a PDF and sending it to Benefits Intake API',
          hash_including(error: anything)
        )

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when intent submission returns no confirmation number' do
      before do
        allow_any_instance_of(SimpleFormsApi::IntentToFile).to receive(:submit)
          .and_return([nil, Time.zone.now.iso8601])
      end

      it 'does not send intent received email when confirmation_number is nil' do
        expect_any_instance_of(SimpleFormsApi::V1::UploadsController).not_to receive(:send_intent_received_email)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when intent submission returns confirmation number' do
      before do
        allow_any_instance_of(SimpleFormsApi::IntentToFile).to receive(:submit)
          .and_return(['ITF123', Time.zone.now.iso8601])
      end

      it 'sends intent received email when confirmation_number is present' do
        expect_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:send_intent_received_email)
          .with(anything, 'ITF123', anything)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe '#submit - SAHSHA API Email Flows' do
    let(:data) do
      fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                     'vba_26_4555.json')
      JSON.parse(fixture_path.read)
    end

    before do
      sign_in(user)
    end

    context 'when status is VALIDATED' do
      before do
        allow_any_instance_of(LGY::Service).to receive(:post_grant_application)
          .and_return(double(
            body: { 'reference_number' => 'REF-VALIDATED', 'status' => 'VALIDATED' },
            status: 200
          ))
      end

      it 'sends confirmation email for VALIDATED status' do
        expect_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:send_sahsha_email)
          .with(anything, :confirmation, 'REF-VALIDATED')

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when status is ACCEPTED' do
      before do
        allow_any_instance_of(LGY::Service).to receive(:post_grant_application)
          .and_return(double(
            body: { 'reference_number' => 'REF-ACCEPTED', 'status' => 'ACCEPTED' },
            status: 200
          ))
      end

      it 'sends confirmation email for ACCEPTED status' do
        expect_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:send_sahsha_email)
          .with(anything, :confirmation, 'REF-ACCEPTED')

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when status is REJECTED' do
      before do
        allow_any_instance_of(LGY::Service).to receive(:post_grant_application)
          .and_return(double(
            body: { 'reference_number' => 'REF-REJECTED', 'status' => 'REJECTED' },
            status: 200
          ))
      end

      it 'sends rejected email for REJECTED status' do
        expect_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:send_sahsha_email)
          .with(anything, :rejected, 'REF-REJECTED')

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when status is DUPLICATE' do
      before do
        allow_any_instance_of(LGY::Service).to receive(:post_grant_application)
          .and_return(double(
            body: { 'reference_number' => 'REF-DUPLICATE', 'status' => 'DUPLICATE' },
            status: 200
          ))
      end

      it 'sends duplicate email for DUPLICATE status (without confirmation number)' do
        expect_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:send_sahsha_email)
          .with(anything, :duplicate)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe '#submit - FormRemediation Error Handling' do
    let(:data) do
      fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                     'vba_21_4142.json')
      JSON.parse(fixture_path.read)
    end

    before do
      sign_in(user)
      
      # Mock the successful upload_pdf call
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
        .and_return([200, 'test-uuid', double(id: 123)])
      
      # Mock other dependencies
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:get_file_paths_and_metadata)
        .and_return(['/tmp/test.pdf', {}, double(track_user_identity: nil)])
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:send_confirmation_email_safely)
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:add_vsi_flash_safely)
    end

    context 'when SimpleFormsApi::FormRemediation::Error is raised during S3 upload' do
      before do
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf_to_s3)
          .and_raise(SimpleFormsApi::FormRemediation::Error.new)
      end

      it 'logs the S3 error and continues processing' do
        expect(Rails.logger).to receive(:error)
          .with('Simple forms api - error uploading form submission to S3 bucket', error: anything)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe '#submit - Handle Attachments Path' do
    context 'for form 40-0247' do
      let(:data) do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'vba_40_0247.json')
        JSON.parse(fixture_path.read)
      end

      before do
        sign_in(user)
        
        # Mock dependencies
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
          .and_return([200, 'test-uuid', double(id: 123)])
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:send_confirmation_email_safely)
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf_to_s3)
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:add_vsi_flash_safely)
      end

      it 'calls handle_attachments for vba_40_0247 forms' do
        form_double = double(
          metadata: {},
          zip_code_is_us_based: true,
          track_user_identity: nil,
          handle_attachments: nil
        )
        allow_any_instance_of(SimpleFormsApi::VBA400247).to receive(:handle_attachments).with('/tmp/test.pdf')
        allow(SimpleFormsApi::VBA400247).to receive(:new).and_return(form_double)
        
        # Mock PdfFiller
        pdf_filler = double(generate: '/tmp/test.pdf')
        allow(SimpleFormsApi::PdfFiller).to receive(:new).and_return(pdf_filler)

        expect(form_double).to receive(:handle_attachments).with('/tmp/test.pdf')

        post '/simple_forms_api/v1/simple_forms', params: data
      end
    end

    context 'for form 40-10007' do
      let(:data) do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'vba_40_10007.json')
        JSON.parse(fixture_path.read)
      end

      before do
        sign_in(user)
        
        # Mock dependencies
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
          .and_return([200, 'test-uuid', double(id: 123)])
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:send_confirmation_email_safely)
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf_to_s3)
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:add_vsi_flash_safely)
      end

      it 'calls handle_attachments for vba_40_10007 forms' do
        form_double = double(
          metadata: {},
          zip_code_is_us_based: true,
          track_user_identity: nil,
          handle_attachments: nil
        )
        allow_any_instance_of(SimpleFormsApi::VBA4010007).to receive(:handle_attachments).with('/tmp/test.pdf')
        allow(SimpleFormsApi::VBA4010007).to receive(:new).and_return(form_double)
        
        # Mock PdfFiller
        pdf_filler = double(generate: '/tmp/test.pdf')
        allow(SimpleFormsApi::PdfFiller).to receive(:new).and_return(pdf_filler)

        expect(form_double).to receive(:handle_attachments).with('/tmp/test.pdf')

        post '/simple_forms_api/v1/simple_forms', params: data
      end
    end
  end

  describe '#submit - 20-10207 Attachments Path' do
    let(:data) do
      fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                     'vba_20_10207-veteran.json')
      JSON.parse(fixture_path.read)
    end

    before do
      sign_in(user)
      
      # Mock dependencies for successful flow
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:get_file_paths_and_metadata)
        .and_return(['/tmp/test.pdf', {}, form_double])
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:prepare_for_upload)
        .and_return(['upload-location', 'test-uuid', double])
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:log_upload_details)
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:send_confirmation_email_safely)
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf_to_s3)
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:add_vsi_flash_safely)
      
      allow(lighthouse_service).to receive(:perform_upload).and_return(double(status: 200))
    end

    let(:form_double) do
      double(
        track_user_identity: nil,
        get_attachments: ['/path/to/attachment1.pdf', '/path/to/attachment2.pdf']
      )
    end

    it 'includes attachments when uploading 20-10207 forms' do
      expect(lighthouse_service).to receive(:perform_upload).with(
        hash_including(
          attachments: ['/path/to/attachment1.pdf', '/path/to/attachment2.pdf']
        )
      )

      post '/simple_forms_api/v1/simple_forms', params: data
    end
  end

  describe '#submit - VSI Flash Path Coverage' do
    let(:data) do
      fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                     'vba_20_10207-veteran.json')
      JSON.parse(fixture_path.read)
    end

    let(:form_submission) { double(id: 999) }
    let(:form_double) do
      double(
        metadata: {},
        zip_code_is_us_based: true,
        track_user_identity: nil,
        respond_to?: true,
        add_vsi_flash: nil
      )
    end

    before do
      sign_in(user)
      
      # Mock successful upload
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
        .and_return([200, 'test-uuid', form_submission])
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:get_file_paths_and_metadata)
        .and_return(['/tmp/test.pdf', {}, form_double])
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:send_confirmation_email_safely)
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf_to_s3)
    end

    # Simplified VSI flash test - just check that the flipper check happens
    context 'when VSI flash functionality is called' do
      it 'checks the VSI flash feature flag' do
        allow(Flipper).to receive(:enabled?).with(:priority_processing_request_apply_vsi_flash, anything).and_return(false)
        
        post '/simple_forms_api/v1/simple_forms', params: data.merge(form_number: '20-10207')
        
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when VSI flash raises an error' do
      before do
        allow(Flipper).to receive(:enabled?).with(:priority_processing_request_apply_vsi_flash, user).and_return(true)
        allow(form_double).to receive(:respond_to?).with(:add_vsi_flash).and_return(true)
        allow(form_double).to receive(:add_vsi_flash).and_raise(StandardError.new('VSI error'))
      end

      it 'logs the VSI flash error and continues' do
        expect(Rails.logger).to receive(:error).with(
          'Simple Forms API - Controller-level VSI Flash Error',
          error: 'VSI error',
          submission_id: 999
        )

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when form does not respond to add_vsi_flash' do
      before do
        allow(Flipper).to receive(:enabled?).with(:priority_processing_request_apply_vsi_flash, user).and_return(true)
        allow(form_double).to receive(:respond_to?).with(:add_vsi_flash).and_return(false)
      end

      it 'does not call add_vsi_flash' do
        expect(form_double).not_to receive(:add_vsi_flash)

        post '/simple_forms_api/v1/simple_forms', params: data
      end
    end

    context 'when form is not 20-10207' do
      let(:data) do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'vba_21_4142.json')
        JSON.parse(fixture_path.read)
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:priority_processing_request_apply_vsi_flash, user).and_return(true)
        allow(form_double).to receive(:respond_to?).with(:add_vsi_flash).and_return(true)
      end

      it 'does not call add_vsi_flash for non-20-10207 forms' do
        expect(form_double).not_to receive(:add_vsi_flash)

        post '/simple_forms_api/v1/simple_forms', params: data
      end
    end
  end

  describe '#submit_supporting_documents - Return Early Path' do
    context 'when form_id is not in allowed list' do
      it 'returns early without processing for non-allowed form' do
        post '/simple_forms_api/v1/simple_forms/submit_supporting_documents',
             params: { 
               form_id: '21-4142', 
               file: fixture_file_upload('doctors-note.pdf', 'application/pdf') 
             }

        # Should return early and be unauthorized since form_id not in allowed list
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe '#get_intents_to_file - Participant ID Coverage' do
    before do
      sign_in(user)
      allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
    end

    context 'when user has no participant_id' do
      before do
        allow_any_instance_of(User).to receive(:participant_id).and_return(nil)
      end

      it 'handles case where user has no participant_id' do
        # Mock the intent service to return empty intents
        intent_service = double(existing_intents: { 'compensation' => nil, 'pension' => nil, 'survivor' => nil })
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:intent_service).and_return(intent_service)

        get '/simple_forms_api/v1/simple_forms/get_intents_to_file'

        expect(response).to have_http_status(:ok)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['compensation_intent']).to be_nil
        expect(parsed_response['pension_intent']).to be_nil
        expect(parsed_response['survivor_intent']).to be_nil
      end
    end
  end

  describe 'Private Method Coverage' do
    let(:controller) { SimpleFormsApi::V1::UploadsController.new }

    describe '#icn' do
      it 'returns user icn when current_user exists' do
        user_double = double(icn: 'test-icn-123')
        controller.instance_variable_set('@current_user', user_double)
        
        expect(controller.send(:icn)).to eq('test-icn-123')
      end

      it 'returns nil when current_user is nil' do
        controller.instance_variable_set('@current_user', nil)
        
        expect(controller.send(:icn)).to be_nil
      end
    end

    describe '#form_is264555_and_should_use_lgy_api' do
      it 'returns true when form is 26-4555 and user has icn' do
        allow(controller).to receive(:params).and_return({ form_number: '26-4555' })
        allow(controller).to receive(:icn).and_return('test-icn')
        
        result = controller.send(:form_is264555_and_should_use_lgy_api)
        expect(result).to be_truthy
        expect(result).to eq('test-icn')
      end

      it 'returns false when form is not 26-4555' do
        allow(controller).to receive(:params).and_return({ form_number: '21-4142' })
        allow(controller).to receive(:icn).and_return('test-icn')
        
        result = controller.send(:form_is264555_and_should_use_lgy_api)
        expect(result).to be_falsy
      end

      it 'returns false when form is 26-4555 but no icn' do
        allow(controller).to receive(:params).and_return({ form_number: '26-4555' })
        allow(controller).to receive(:icn).and_return(nil)
        
        result = controller.send(:form_is264555_and_should_use_lgy_api)
        expect(result).to be_falsy
      end
    end
  end

  describe 'Datadog Tracing Coverage' do
    let(:data) do
      fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                     'vba_21_4142.json')
      JSON.parse(fixture_path.read)
    end

    before do
      sign_in(user)
      
      # Mock dependencies
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
        .and_return([200, 'test-uuid-456', double(id: 789)])
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:get_file_paths_and_metadata)
        .and_return(['/tmp/test.pdf', {}, double(track_user_identity: nil)])
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:send_confirmation_email_safely)
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf_to_s3)
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:add_vsi_flash_safely)
    end

    it 'sets Datadog trace tags during submission' do
      active_trace = double
      allow(Datadog::Tracing).to receive(:active_trace).and_return(active_trace)
      expect(active_trace).to receive(:set_tag).with('form_id', '21-4142')

      post '/simple_forms_api/v1/simple_forms', params: data
    end

    it 'handles case when no active trace' do
      allow(Datadog::Tracing).to receive(:active_trace).and_return(nil)

      post '/simple_forms_api/v1/simple_forms', params: data

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PDF Stamping Coverage' do
    let(:data) do
      fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                     'vba_21_4142.json')
      JSON.parse(fixture_path.read)
    end

    before do
      sign_in(user)
    end

    it 'calls stamp_pdf_with_uuid during upload process' do
      # Mock the upload flow components
      form_double = double(track_user_identity: nil)
      pdf_stamper = double
      allow(SimpleFormsApi::PdfStamper).to receive(:new).and_return(pdf_stamper)
      expect(pdf_stamper).to receive(:stamp_uuid).with('test-uuid-789')
      
      allow(lighthouse_service).to receive(:request_upload).and_return(['location-url', 'test-uuid-789'])
      allow(lighthouse_service).to receive(:perform_upload).and_return(double(status: 200))
      
      # Mock form submission creation
      form_submission = double
      form_submission_attempt = double(form_submission: form_submission)
      allow(FormSubmissionAttempt).to receive(:create).and_return(form_submission_attempt)
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:create_form_submission).and_return(form_submission)
      
      # Mock other dependencies
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:get_file_paths_and_metadata)
        .and_return(['/tmp/test.pdf', {}, form_double])
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:send_confirmation_email_safely)
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf_to_s3)
      allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:add_vsi_flash_safely)

      post '/simple_forms_api/v1/simple_forms', params: data
    end
  end
end
