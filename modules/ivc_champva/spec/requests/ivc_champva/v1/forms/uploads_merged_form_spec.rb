# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_context 'with temporary file cleanup' do
  def with_temporary_file(file_path)
    yield file_path
  ensure
    FileUtils.rm_f(file_path)
  end
end

RSpec.describe 'IvcChampva::V1::Forms::Uploads - submit_champva_app_merged', type: :request do
  include_context 'with temporary file cleanup'

  describe '#submit_champva_app_merged' do
    let(:controller) { IvcChampva::V1::UploadsController.new }

    # A full test data object including a full 10-10d with an applicant in need of an OHI form.
    let(:form_data) do
      JSON.parse(Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json',
                                 'vha_10_10d_extended.json').read)
    end

    # Reusable applicant data
    let(:applicant) do
      {
        'first_name' => 'John',
        'last_name' => 'Doe',
        'applicant_ssn' => '123456789',
        'applicant_has_ohi' => { 'has_ohi' => 'yes' }
      }
    end

    # Reusable test form
    let(:test_form) do
      {
        'form_number' => '10-10D',
        'veteran' => {
          'full_name' => { 'first' => 'Veteran', 'last' => 'Smith' }
        },
        'applicants' => [applicant]
      }
    end

    # Reusable OHI form instance
    let(:ohi_form) { controller.send(:generate_ohi_form, applicant, test_form) }

    # Mock environment setting for the time being (this is hard disabled in production)
    let!(:environment_setting) { allow(Settings).to receive(:vsp_environment).and_return('staging') }

    # S3 client for file uploads
    let(:s3_client) do
      instance_double(Aws::S3::Client).tap do |client|
        # Create a simpler mock response instead of trying to mock complex AWS response objects
        response = double('S3Response')
        # Only mock the methods and properties actually used by the code
        http_response = instance_double(Seahorse::Client::Http::Response, status_code: 200)
        context = instance_double(Seahorse::Client::RequestContext, http_response:)
        allow(response).to receive(:context).and_return(context)
        # allow(response).to receive_message_chain(:context, :http_response, :status_code).and_return(200)
        allow(client).to receive(:put_object).and_return(response)
      end
    end

    before do
      # Setup common mocks for all tests
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)

      # Mock handle_file_uploads_wrapper method for our specific controller
      allow(controller).to receive(:handle_file_uploads_wrapper).and_return(
        { status: 200, messages: ['Success'] }
      )
    end

    # --- INTEGRATION TESTS ---

    describe 'integration tests' do
      # Stub the controller instance that's created during the request
      let(:request_controller) { controller }

      before do
        # Stub the controller that will be created during the request processing
        allow(IvcChampva::V1::UploadsController).to receive(:new).and_return(request_controller)
      end

      it 'successfully processes a basic form submission without errors' do
        # Set expectations for the private methods
        expect(request_controller).to receive(:generate_ohi_form).once.and_call_original
        expect(request_controller).to receive(:create_custom_attachment).once.and_call_original
        expect(request_controller).to receive(:add_supporting_doc).once.and_call_original

        post '/ivc_champva/v1/forms/10-10d-ext', params: form_data

        # The controller should return success
        expect(response).to be_successful
      end

      it 'adds OHI forms as supporting documents to the submission' do
        # Capture the actual data passed to the submit method
        submitted_data = nil

        # Mock the submit method to capture the form data
        allow(request_controller).to receive(:submit) do |form_data|
          submitted_data = form_data
          nil
        end

        # Make request with OHI applicant
        post '/ivc_champva/v1/forms/10-10d-ext', params: form_data

        # Verify OHI forms were added as supporting documents
        expect(submitted_data['supporting_docs']).not_to be_empty
        expect(submitted_data['supporting_docs'].any? { |doc| doc['attachment_id'] == 'VA form 10-7959c' }).to be true
      end

      it 'handles errors during OHI form generation' do
        # Mock generate_ohi_form to raise an error
        allow(request_controller).to receive(:generate_ohi_form).and_raise('Test error')

        post '/ivc_champva/v1/forms/10-10d-ext', params: form_data

        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)['error_message']).to include('Error submitting merged form')
      end
    end

    # --- UNIT TESTS ---

    describe 'generate_ohi_form' do
      it 'correctly generates an OHI form with applicant data' do
        # Need to make the private method accessible for testing
        form = controller.send(:generate_ohi_form, applicant, form_data)

        # Verify the form has the correct properties
        expect(form[0]).to be_a(IvcChampva::VHA107959cRev2025)
        expect(form[0].data['first_name']).to eq('John')
        expect(form[0].data['last_name']).to eq('Doe')
        expect(form[0].data['form_number']).to eq('10-7959C')

        # Verify the form contains other data from the original form_data
        expect(form[0].data['veteran']).to eq(form_data['veteran'])
      end
    end

    describe 'create_custom_attachment' do
      it 'creates a persistent attachment record' do
        # Create a mock form with required attributes
        form = instance_double(
          IvcChampva::VHA107959cRev2025,
          form_id: '10-7959C-REV2025',
          uuid: 'test-uuid',
          data: {
            'first_name' => 'John',
            'last_name' => 'Doe'
          }
        )

        # Create a temporary file to simulate the generated PDF
        temp_pdf_path = Rails.root.join('tmp', "test_ohi_form_#{Time.now.to_i}.pdf")
        File.write(temp_pdf_path, 'Mock PDF content')

        with_temporary_file(temp_pdf_path) do |path|
          # Mock fill_ohi_and_return_path to return our temp file path
          allow(controller).to receive(:fill_ohi_and_return_path).with(form).and_return(path)

          # Call the private method
          attachment_data = controller.send(:create_custom_attachment, form, path, 'VA form 10-7959c')

          # Verify the attachment was created with expected data
          expect(attachment_data).not_to be_nil
          expect(attachment_data).to include('name')
          expect(attachment_data).to include('attachment_id' => 'VA form 10-7959c')
        end
      end
    end

    describe 'fill_ohi_and_return_path' do
      it 'generates a PDF file' do
        # Generate the OHI form
        form = controller.send(:generate_ohi_form, applicant, form_data)

        # Call the private method to generate the PDF
        pdf_path = controller.send(:fill_ohi_and_return_path, form[0])

        with_temporary_file(pdf_path) do |path|
          # Verify the PDF file was created
          expect(File.exist?(path)).to be true

          # Verify it's actually a PDF by checking file signature
          pdf_signature = File.binread(path, 4)
          expect(pdf_signature).to eq('%PDF')

          # Verify the file has a reasonable size (more than 1KB)
          expect(File.size(path)).to be > 1024
        end
      end
    end

    # --- EDGE CASES ---

    describe 'applicants_with_ohi' do
      it 'filters applicants with OHI correctly' do
        applicants = [
          { 'first_name' => 'John', 'health_insurance' => [{}] },
          { 'first_name' => 'Jane' },
          { 'first_name' => 'Bob', 'health_insurance' => [{}] }
        ]

        result = controller.send(:applicants_with_ohi, applicants)

        expect(result.length).to eq(2)
        expect(result.map { |a| a['first_name'] }).to contain_exactly('John', 'Bob')
      end

      it 'handles empty applicant array' do
        result = controller.send(:applicants_with_ohi, [])
        expect(result).to be_empty
      end

      it 'handles missing has_ohi field' do
        applicants = [
          { 'first_name' => 'John', 'health_insurance' => [{}] },
          { 'first_name' => 'Jane' },
          { 'first_name' => 'Bob' }
        ]

        result = controller.send(:applicants_with_ohi, applicants)

        expect(result.length).to eq(1)
        expect(result.first['first_name']).to eq('John')
      end
    end
  end
end
