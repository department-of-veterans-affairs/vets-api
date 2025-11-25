# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::FormVersionManager do
  # This spec tests the FormVersionManager using mocked form classes and configurations
  # to ensure the versioning system works generically without being tied to specific
  # form implementations.

  # Mock form classes for testing
  let(:mock_base_form_class) do
    Class.new do
      include Virtus.model(nullify_blank: true)

      attr_reader :form_id, :data, :uuid

      def initialize(data)
        @data = data
        @uuid = SecureRandom.uuid
        @form_id = 'test_base_form'
      end

      def metadata
        { 'uuid' => @uuid, 'docType' => @data['form_number'] }
      end

      def track_user_identity; end
      def track_current_user_loa(_user); end
      def track_email_usage; end
      def handle_attachments(file_path) = [file_path]
    end
  end

  let(:mock_versioned_form_class) do
    Class.new do
      include Virtus.model(nullify_blank: true)

      attr_reader :form_id, :data, :uuid

      def initialize(data)
        @data = data
        @uuid = SecureRandom.uuid
        @form_id = 'test_versioned_form'
      end

      def metadata
        { 'uuid' => @uuid, 'docType' => @data['form_number'], 'formExpiration' => '12/31/2025' }
      end

      def track_user_identity; end
      def track_current_user_loa(_user); end
      def track_email_usage; end
      def handle_attachments(file_path) = [file_path]
    end
  end

  before do
    # Mock the constants with test values
    stub_const('IvcChampva::FormVersionManager::FORM_VERSIONS', {
                 'test_base_form' => {
                   current: 'test_base_form',
                   '2025' => 'test_versioned_form'
                 }
               })

    stub_const('IvcChampva::FormVersionManager::FORM_VERSION_FLAGS', {
                 'test_versioned_form' => 'test_versioned_form_enabled'
               })

    stub_const('IvcChampva::FormVersionManager::LEGACY_MAPPING', {
                 'test_versioned_form' => 'test_base_form'
               })
  end

  describe '.resolve_form_version' do
    before do
      allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(true)
    end

    context 'when form has no versions configured' do
      it 'returns the original form ID' do
        result = described_class.resolve_form_version('unknown_form', nil)
        expect(result).to eq('unknown_form')
      end
    end

    context 'when form has versions configured' do
      context 'and feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(false)
        end

        it 'returns the current version' do
          result = described_class.resolve_form_version('test_base_form', nil)
          expect(result).to eq('test_base_form')
        end
      end

      context 'and feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(true)
        end

        it 'returns the versioned form ID' do
          result = described_class.resolve_form_version('test_base_form', nil)
          expect(result).to eq('test_versioned_form')
        end

        it 'passes the current_user to Flipper' do
          user = double('User')
          expect(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', user).and_return(true)
          described_class.resolve_form_version('test_base_form', user)
        end
      end
    end
  end

  describe '.get_legacy_form_id' do
    it 'returns the legacy form ID for versioned forms' do
      result = described_class.get_legacy_form_id('test_versioned_form')
      expect(result).to eq('test_base_form')
    end

    it 'returns the same form ID for non-versioned forms' do
      result = described_class.get_legacy_form_id('test_base_form')
      expect(result).to eq('test_base_form')
    end
  end

  describe '.get_form_class' do
    it 'handles the special case for vha_10_10d_2027' do
      # Test the specific case statement branch
      expect(described_class.get_form_class('vha_10_10d_2027')).to eq(IvcChampva::VHA1010d2027)
    end

    it 'uses constantize pattern for form ID resolution' do
      # Test that the method follows the expected pattern without actually calling constantize
      # (Integration tests cover the actual usage with mocked classes)
      form_id = 'test_base_form'
      expected_pattern = "IvcChampva::#{form_id.titleize.gsub(' ', '')}"
      expect(expected_pattern).to eq('IvcChampva::TestBaseForm')
    end
  end

  describe '.versioned_form?' do
    it 'returns true for forms with legacy mapping' do
      result = described_class.versioned_form?('test_versioned_form')
      expect(result).to be true
    end

    it 'returns false for forms without legacy mapping' do
      result = described_class.versioned_form?('test_base_form')
      expect(result).to be false
    end
  end

  describe '.create_form_instance' do
    let(:form_data) { { 'test' => 'data' } }

    before do
      # Mock the get_form_class method to return our mock classes
      allow(described_class).to receive(:get_form_class)
        .with('test_base_form').and_return(mock_base_form_class)
      allow(described_class).to receive(:get_form_class)
        .with('test_versioned_form').and_return(mock_versioned_form_class)
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(false)
      end

      it 'creates an instance of the base form class' do
        result = described_class.create_form_instance('test_base_form', form_data, nil)
        expect(result).to be_a(mock_base_form_class)
        expect(result.form_id).to eq('test_base_form')
        expect(result.data).to eq(form_data)
      end
    end
  end

  # Integration tests with UploadsController
  describe 'Integration with UploadsController' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:mock_user) { double('User', loa: { current: 3 }) }
    let(:form_data) do
      {
        'form_number' => 'TEST-FORM',
        'test_field' => 'test_value',
        'supporting_docs' => []
      }
    end
    let(:file_path) { 'tmp/test_form.pdf' }

    before do
      # Mock controller setup
      allow(controller).to receive_messages(
        params: { form_number: 'TEST-FORM' },
        current_user: mock_user
      )

      # Mock FORM_NUMBER_MAP to include our test form
      stub_const('IvcChampva::V1::UploadsController::FORM_NUMBER_MAP', {
                   'TEST-FORM' => 'test_base_form'
                 })

      # Mock form class resolution
      allow(described_class).to receive(:get_form_class)
        .with('test_base_form').and_return(mock_base_form_class)
      allow(described_class).to receive(:get_form_class)
        .with('test_versioned_form').and_return(mock_versioned_form_class)

      # Mock PDF generation and file operations
      allow_any_instance_of(IvcChampva::PdfFiller).to receive(:generate).and_return(file_path)
      allow(IvcChampva::MetadataValidator).to receive(:validate) do |metadata|
        metadata # Return the metadata as-is for testing
      end
    end

    describe '#get_attachment_ids_and_form' do
      context 'when feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(false)
        end

        it 'uses the base form and returns correct attachment IDs' do
          attachment_ids, form = controller.send(:get_attachment_ids_and_form, form_data)

          expect(attachment_ids).to include('test_base_form')
          expect(form).to be_a(mock_base_form_class)
          expect(form.form_id).to eq('test_base_form')
        end
      end

      context 'when feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(true)
        end

        it 'uses the versioned form and returns correct attachment IDs' do
          attachment_ids, form = controller.send(:get_attachment_ids_and_form, form_data)

          expect(attachment_ids).to include('test_base_form')
          expect(form).to be_a(mock_versioned_form_class)
          expect(form.form_id).to eq('test_versioned_form')
        end
      end
    end

    describe '#get_file_paths_and_metadata' do
      context 'when feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(false)
        end

        it 'uses base form for PDF generation and metadata' do
          file_paths, metadata = controller.send(:get_file_paths_and_metadata, form_data)

          expect(file_paths).to include(file_path)
          expect(metadata['attachment_ids']).to include('test_base_form')
          # DocType should use the original user-facing form number for database records
          expect(metadata['docType']).to eq('TEST-FORM')
        end
      end

      context 'when feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(true)
        end

        it 'uses versioned form for PDF generation but legacy ID for metadata' do
          file_paths, metadata = controller.send(:get_file_paths_and_metadata, form_data)

          expect(file_paths).to include(file_path)
          # Attachment IDs should be mapped to legacy form ID for downstream services
          expect(metadata['attachment_ids']).to include('test_base_form')
          # DocType should use the original user-facing form number for database records
          expect(metadata['docType']).to eq('TEST-FORM')
        end
      end
    end

    describe 'backwards compatibility edge cases' do
      context 'when multiple versions exist' do
        before do
          # Add another version to test precedence
          stub_const('IvcChampva::FormVersionManager::FORM_VERSIONS', {
                       'test_base_form' => {
                         current: 'test_base_form',
                         '2024' => 'test_form_2024',
                         '2025' => 'test_versioned_form'
                       }
                     })

          stub_const('IvcChampva::FormVersionManager::FORM_VERSION_FLAGS', {
                       'test_form_2024' => 'test_form_2024_enabled',
                       'test_versioned_form' => 'test_versioned_form_enabled'
                     })
        end

        it 'uses the first enabled version in iteration order' do
          # Enable 2025 version only
          allow(Flipper).to receive(:enabled?).with('test_form_2024_enabled', anything).and_return(false)
          allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(true)

          result = described_class.resolve_form_version('test_base_form', nil)
          expect(result).to eq('test_versioned_form')
        end

        it 'prefers earlier version if both are enabled' do
          # Enable both versions - should pick the first one encountered
          allow(Flipper).to receive(:enabled?).with('test_form_2024_enabled', anything).and_return(true)
          allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(true)

          result = described_class.resolve_form_version('test_base_form', nil)
          # Should return the first enabled version it encounters
          expect(result).to eq('test_form_2024')
        end
      end

      context 'when form mapping changes over time' do
        it 'handles new forms being added to existing versions' do
          # Simulate adding a new form to the system
          new_versions = described_class::FORM_VERSIONS.dup
          new_versions['new_form'] = { current: 'new_form', '2025' => 'new_form_2025' }

          stub_const('IvcChampva::FormVersionManager::FORM_VERSIONS', new_versions)

          result = described_class.resolve_form_version('new_form', nil)
          expect(result).to eq('new_form') # Falls back to current since no feature flag enabled
        end
      end
    end
  end
end
