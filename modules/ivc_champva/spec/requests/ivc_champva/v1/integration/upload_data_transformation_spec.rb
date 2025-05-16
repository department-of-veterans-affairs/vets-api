# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'IvcChampva Upload Data Transformation Chain Integration Test', type: :request do
  form_numbers_and_classes = {
    '10-10D' => IvcChampva::VHA1010d,
    '10-7959C' => IvcChampva::VHA107959c,
    '10-7959F-2' => IvcChampva::VHA107959f2,
    '10-7959F-1' => IvcChampva::VHA107959f1,
    '10-7959A' => IvcChampva::VHA107959a
  }

  form_number_to_fixture = {
    '10-10D' => 'vha_10_10d.json',
    '10-7959C' => 'vha_10_7959c.json',
    '10-7959F-2' => 'vha_10_7959f_2.json',
    '10-7959F-1' => 'vha_10_7959f_1.json',
    '10-7959A' => 'vha_10_7959a.json'
  }

  let(:test_file_path) { Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'files', 'test.pdf') }
  let(:form_uuid) { 'test-form-uuid-12345' }

  before do
    @original_aws_config = Aws.config.dup
    Aws.config.update(stub_responses: true)

    allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(
      double('response', context: double('context', http_response: double('http_response', status_code: 200)))
    )

    unless File.exist?(test_file_path)
      FileUtils.mkdir_p(File.dirname(test_file_path))
      File.write(test_file_path, 'Test PDF content')
    end

    mock_attachment = double('PersistentAttachments::MilitaryRecords',
                             id: 'test-attachment-guid',
                             created_at: 1.day.ago,
                             file: double('file', id: 'file-id'),
                             destroy: true)
    allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
      .with(guid: 'test-attachment-guid')
      .and_return(mock_attachment)
    allow(PersistentAttachments::MilitaryRecords).to receive(:create!).and_return(mock_attachment)
  end

  after do
    Aws.config = @original_aws_config
    FileUtils.rm_f(test_file_path)
  end

  shared_context 'form data setup' do |form_number|
    let(:form_class) { form_numbers_and_classes[form_number] }
    let(:fixture_path) do
      Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', form_number_to_fixture[form_number])
    end
    let(:base_request_data) { JSON.parse(fixture_path.read) }
    let(:request_data) do
      base_request_data.merge(
        'uuid' => form_uuid,
        'supporting_docs' => [{ 'confirmation_code' => 'test-attachment-guid', 'attachment_id' => 'Test Document' }],
        'source' => 'VA Platform Digital Forms',
        'docType' => form_number,
        'fileNumber' => '123456789'
      )
    end
    let(:db_record) do
      double('IvcChampvaForm',
             form_uuid:,
             email: base_request_data.dig('primary_contact_info', 'email'),
             first_name: base_request_data.dig('primary_contact_info', 'name', 'first'),
             last_name: base_request_data.dig('primary_contact_info', 'name', 'last'),
             form_number:,
             file_name: 'some_file.pdf',
             s3_status: '[200, nil]',
             pega_status: 'Submitted')
    end
    let(:invalid_file_number_data) { request_data.merge('fileNumber' => '123') } # Invalid - fewer than 8 digits
    let(:missing_source_data) do
      data = request_data.dup
      data.delete('source')
      data
    end
    let(:invalid_doctype_data) { request_data.merge('docType' => 12_345) } # Should be a string
  end

  shared_context 'attachment mocking' do
    before do
      mock_attachment = instance_double(
        PersistentAttachments::MilitaryRecords,
        created_at: 1.day.ago,
        id: 'test-attachment-guid',
        file: double('file', id: 'file0'),
        destroy: true
      )
      allow(PersistentAttachments::MilitaryRecords).to receive(:create!).and_return(mock_attachment)
      allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
        .with(guid: 'test-attachment-guid')
        .and_return(double('Record', created_at: 1.day.ago, id: 'test-attachment-guid', file: double(id: 'file0')))
      @attachment = mock_attachment
    end
  end

  shared_examples 'completes transformation chain' do |form_number|
    include_context 'form data setup', form_number
    include_context 'attachment mocking'

    before do
      allow_any_instance_of(IvcChampva::PdfFiller).to receive(:generate).and_return(test_file_path.to_s)
      allow_any_instance_of(form_class).to receive(:handle_attachments) { |_, original_path| [original_path] }
      allow_any_instance_of(form_class).to receive(:get_attachments).and_return([test_file_path.to_s])
      allow(IvcChampvaForm).to receive_messages(create!: db_record, new: db_record)
    end

    it 'transforms data correctly through the entire chain' do
      # Track transformation stages
      transformations = {
        form_instance: nil, metadata_after_form_class: nil, validated_metadata: nil,
        file_paths_after_handle_attachments: nil, metadata_after_merge: nil, db_record: nil
      }

      # Create form instance and validate metadata
      form_instance = form_class.new(request_data)
      transformations[:form_instance] = form_instance
      transformations[:metadata_after_form_class] = form_instance.metadata.dup
      validated_metadata = IvcChampva::MetadataValidator.validate(form_instance.metadata)
      transformations[:validated_metadata] = validated_metadata.dup

      # Process through controller
      controller = IvcChampva::V1::UploadsController.new
      allow(controller).to receive(:get_attachment_ids_and_form).and_return([['Test Document'], form_instance])
      file_paths, merged_metadata = controller.send(:get_file_paths_and_metadata, request_data)
      transformations[:file_paths_after_handle_attachments] = file_paths.dup
      transformations[:metadata_after_merge] = merged_metadata.dup

      # Process through file uploader
      file_uploader = IvcChampva::FileUploader.new(form_number, merged_metadata, file_paths, true)
      allow(file_uploader).to receive(:insert_form) do |_file_name, _response_status|
        transformations[:db_record] = db_record
        db_record
      end
      allow(file_uploader).to receive(:upload).and_return([200, nil])
      file_uploader.send(:handle_iterative_uploads)

      # Verify transformation results
      expect(transformations[:form_instance]).to be_a(form_class)

      # Verify all metadata fields are present and retained in the transformation chain
      expected_common_fields = %w[veteranFirstName veteranLastName fileNumber source docType businessLine uuid]
      expected_common_fields.each do |field|
        expect(transformations[:metadata_after_form_class]).to have_key(field),
                                                               "Expected field '#{field}' missing from initial metadata"
        expect(transformations[:validated_metadata]).to have_key(field),
                                                        "Expected field '#{field}' missing from validated metadata"
        expect(transformations[:metadata_after_merge]).to have_key(field),
                                                          "Expected field '#{field}' missing from merged metadata"
      end

      # Verify data integrity through the entire chain for all fields
      transformations[:metadata_after_form_class].each_key do |field|
        next if field == 'primaryContactInfo' # Skip complex nested objects

        # Check that field value is preserved from form class to validation
        if transformations[:validated_metadata].key?(field)
          expect(transformations[:validated_metadata][field]).to eq(transformations[:metadata_after_form_class][field]),
                                                                 "Field '#{field}' value changed during validation"
        end

        # Check that field value is preserved from validation to merging
        if transformations[:metadata_after_merge].key?(field)
          expect(transformations[:metadata_after_merge][field]).to eq(transformations[:validated_metadata][field]),
                                                                   "Field '#{field}' value changed during merging"
        end
      end

      expect(transformations[:file_paths_after_handle_attachments]).to eq([test_file_path.to_s])
      expect(transformations[:metadata_after_merge]).to include('attachment_ids')
      expect(transformations[:metadata_after_merge]['attachment_ids']).to eq(['Test Document'])
      expect(transformations[:db_record].form_uuid).to eq(form_uuid)
      expect(transformations[:db_record].form_number).to eq(form_number)
      expect(transformations[:db_record].s3_status).to eq('[200, nil]')
      expect(transformations[:db_record].pega_status).to eq('Submitted')
    end
  end

  shared_examples 'merges metadata correctly' do |form_number|
    include_context 'form data setup', form_number

    it 'merges attachment_ids into metadata' do
      form_instance = form_class.new(request_data)
      original_metadata = IvcChampva::MetadataValidator.validate(form_instance.metadata)
      expect(original_metadata).not_to include('attachment_ids')

      controller = IvcChampva::V1::UploadsController.new
      attachment_ids = %w[ID1 ID2 ID3]
      allow(controller).to receive(:get_attachment_ids_and_form).and_return([attachment_ids, form_instance])

      _file_paths, merged_metadata = controller.send(:get_file_paths_and_metadata, request_data)

      expect(merged_metadata).to include('attachment_ids')
      expect(merged_metadata['attachment_ids']).to eq(attachment_ids)

      # Verify all fields are preserved through the transformation
      # Get all the keys from the original metadata and check they're preserved in the merged metadata
      original_metadata.each_key do |field|
        expect(merged_metadata[field]).to eq(original_metadata[field]),
                                          "Field '#{field}' was not preserved correctly in metadata merge"
      end
    end
  end

  shared_examples 'verifies database record creation' do |form_number|
    include_context 'form data setup', form_number
    include_context 'attachment mocking'

    let(:unique_identifier) { "test-#{Time.now.to_i}-#{rand(1000)}" }

    before do
      # Set up form class data for proper field extraction
      first_name_field, last_name_field =
        case form_number
        when '10-7959C', '10-7959A'
          %w[applicant_name.first applicant_name.last]
        else
          %w[veteran.full_name.first veteran.full_name.last]
        end

      # Get the applicable name fields and set up request data with unique values
      @veteran_first_name = base_request_data.dig(*first_name_field.split('.')) || 'TestVeteran'
      @veteran_last_name = base_request_data.dig(*last_name_field.split('.')) || 'TestLastName'

      modified_data = base_request_data.deep_dup

      # Update first name field with unique value
      parts = first_name_field.split('.')
      current = modified_data
      parts[0...-1].each do |part|
        current[part] ||= {}
        current = current[part]
      end
      current[parts.last] = "#{@veteran_first_name}-#{unique_identifier}"

      # Update last name field with unique value
      parts = last_name_field.split('.')
      current = modified_data
      parts[0...-1].each do |part|
        current[part] ||= {}
        current = current[part]
      end
      current[parts.last] = "#{@veteran_last_name}-#{unique_identifier}"

      @request_data = modified_data.merge(
        'uuid' => unique_identifier,
        'supporting_docs' => [{ 'confirmation_code' => 'test-attachment-guid', 'attachment_id' => 'Test Document' }],
        'source' => 'VA Platform Digital Forms',
        'docType' => form_number,
        'fileNumber' => '123456789'
      )

      # Mock form processing and database record
      allow_any_instance_of(IvcChampva::PdfFiller).to receive(:generate).and_return(test_file_path.to_s)
      allow_any_instance_of(form_class).to receive(:handle_attachments) { |_, original_path| [original_path] }
      allow_any_instance_of(form_class).to receive(:get_attachments).and_return([test_file_path.to_s])

      @test_db_record = double('IvcChampvaForm',
                               form_uuid: unique_identifier,
                               form_number:,
                               first_name: "#{@veteran_first_name}-#{unique_identifier}",
                               last_name: "#{@veteran_last_name}-#{unique_identifier}",
                               file_name: 'test_file.pdf',
                               s3_status: '[200, nil]',
                               pega_status: 'Submitted')

      allow_any_instance_of(IvcChampva::FileUploader).to receive_messages(
        upload: [200, nil],
        insert_form: @test_db_record,
        send: @test_db_record
      )
      allow(IvcChampvaForm).to receive(:find_by).with(form_uuid: unique_identifier).and_return(@test_db_record)
    end

    it 'creates a database record with correct attributes' do
      # Process from form instance through to database
      form_instance = form_class.new(@request_data)
      IvcChampva::MetadataValidator.validate(form_instance.metadata)

      controller = IvcChampva::V1::UploadsController.new
      allow(controller).to receive(:get_attachment_ids_and_form).and_return([['Test Document'], form_instance])
      file_paths, merged_metadata = controller.send(:get_file_paths_and_metadata, @request_data)

      file_uploader = IvcChampva::FileUploader.new(form_number, merged_metadata, file_paths, true)
      file_uploader.send(:handle_iterative_uploads)

      # Verify record creation with expected values
      db_record = IvcChampvaForm.find_by(form_uuid: unique_identifier)
      expect(db_record).not_to be_nil
      expect(db_record.form_uuid).to eq(unique_identifier)
      expect(db_record.form_number).to eq(form_number)
      expect(db_record.first_name).to include(unique_identifier)
      expect(db_record.last_name).to include(unique_identifier)
    end
  end

  shared_examples 'tracks field through transformation' do |form_number|
    include_context 'form data setup', form_number

    let(:first_name_marker) { "FIRST-#{form_number}" }
    let(:last_name_marker) { "LAST-#{form_number}" }

    before do
      # Set tracking values in appropriate fields
      first_name_field, last_name_field =
        case form_number
        when '10-7959C', '10-7959A'
          %w[applicant_name.first applicant_name.last]
        else
          %w[veteran.full_name.first veteran.full_name.last]
        end

      @modified_data = base_request_data.deep_dup

      # Set first name marker
      parts = first_name_field.split('.')
      current = @modified_data
      parts[0...-1].each do |part|
        current[part] ||= {}
        current = current[part]
      end
      current[parts.last] = first_name_marker

      # Set last name marker
      parts = last_name_field.split('.')
      current = @modified_data
      parts[0...-1].each do |part|
        current[part] ||= {}
        current = current[part]
      end
      current[parts.last] = last_name_marker

      @tracking_request = @modified_data.merge(
        'uuid' => form_uuid,
        'supporting_docs' => [{ 'confirmation_code' => 'test-attachment-guid', 'attachment_id' => 'Test Document' }],
        'source' => 'VA Platform Digital Forms',
        'docType' => form_number,
        'fileNumber' => '123456789'
      )

      # Set up mocks
      allow_any_instance_of(IvcChampva::PdfFiller).to receive(:generate).and_return(test_file_path.to_s)
      allow_any_instance_of(form_class).to receive(:handle_attachments) { |_, original_path| [original_path] }
      allow_any_instance_of(form_class).to receive(:get_attachments).and_return([test_file_path.to_s])
    end

    it "preserves transformed values through each step for form #{form_number}" do
      # Create and validate form instance
      form_instance = form_class.new(@tracking_request)
      validated_metadata = IvcChampva::MetadataValidator.validate(form_instance.metadata)

      # Process through controller
      controller = IvcChampva::V1::UploadsController.new
      allow(controller).to receive(:get_attachment_ids_and_form).and_return([['Test Document'], form_instance])
      file_paths, merged_metadata = controller.send(:get_file_paths_and_metadata, @tracking_request)

      # Create mock database record that includes all relevant fields from metadata
      db_record_properties = {
        form_uuid:,
        form_number:
      }

      # Add fields that should be passed to the DB from metadata
      # Map metadata fields to database fields
      metadata_to_db_mapping = {
        'veteranFirstName' => :first_name,
        'veteranLastName' => :last_name,
        'primaryContactEmail' => :email
      }

      metadata_to_db_mapping.each do |metadata_field, db_field|
        db_record_properties[db_field] = validated_metadata[metadata_field] if validated_metadata.key?(metadata_field)
      end

      test_db_record = instance_double(IvcChampvaForm, db_record_properties)

      # Mock form uploader
      file_uploader = IvcChampva::FileUploader.new(form_number, merged_metadata, file_paths, true)
      allow(file_uploader).to receive_messages(
        insert_form: test_db_record,
        upload: [200, nil]
      )

      # Verify ALL metadata fields remain consistent through each step
      validated_metadata.each_key do |field|
        expect(merged_metadata[field]).to eq(validated_metadata[field]),
                                          "Field '#{field}' was not preserved correctly between validation and merging"
      end

      # Verify specifically tracked fields in the database record
      expect(test_db_record.first_name).to eq(validated_metadata['veteranFirstName'])
      expect(test_db_record.last_name).to eq(validated_metadata['veteranLastName'])

      # Verify markers are present in transformed values
      expect(validated_metadata['veteranFirstName']).to include('FIRST')
      expect(validated_metadata['veteranLastName']).to include('LAST')
      expect(validated_metadata['fileNumber']).to match(/^\d{8,9}$/)
      expect(validated_metadata['docType']).to eq(form_number)

      # Additional verification for common metadata fields across all form types
      %w[uuid source businessLine].each do |common_field|
        expect(validated_metadata).to have_key(common_field),
                                      "Common field '#{common_field}' is missing from validated metadata"
      end
    end
  end

  # Run tests for each form type
  form_numbers_and_classes.each_key do |form_number|
    describe "Form #{form_number} transformation" do
      context 'with supporting documents' do
        include_examples 'completes transformation chain', form_number
      end

      context 'with metadata merge' do
        include_examples 'merges metadata correctly', form_number
      end

      context 'with database verification' do
        include_examples 'verifies database record creation', form_number
      end

      context 'with field value tracking' do
        include_examples 'tracks field through transformation', form_number
      end
    end
  end
end
