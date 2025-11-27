# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::FormVersionManager do
  # This spec tests the FormVersionManager using generic test form IDs and real form classes
  # to ensure the versioning system works without being tied to specific production forms.
  #
  # We use generic test form IDs (test_base_form, test_versioned_form) to avoid coupling
  # to production forms that may be deprecated and removed over time.

  # Define test form classes that will be dynamically created
  before do
    # Create a base test form class
    test_base_form = Class.new do
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

    # Create a versioned test form class
    test_versioned_form = Class.new do
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

    # Register these classes using stub_const so they're automatically cleaned up
    stub_const('IvcChampva::TestBaseForm', test_base_form)
    stub_const('IvcChampva::TestVersionedForm', test_versioned_form)

    # Stub the form version configuration constants with test values
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
    it 'correctly resolves class names with VHA prefix' do
      # This test ensures the VHA acronym is properly capitalized
      # titleize converts 'test_base_form' -> 'Test Base Form' -> 'TestBaseForm'
      # No VHA prefix issue here, but validates the constantize works
      expect(described_class.get_form_class('test_base_form')).to eq(IvcChampva::TestBaseForm)
    end

    it 'correctly resolves versioned form class names' do
      # This tests that versioned forms can be resolved
      # 'test_versioned_form' -> 'Test Versioned Form' -> 'TestVersionedForm'
      expect(described_class.get_form_class('test_versioned_form')).to eq(IvcChampva::TestVersionedForm)
    end

    it 'handles real VHA form IDs with proper capitalization' do
      # This is a regression test for the VHA capitalization bug
      # Without the VHA fix, this would try to constantize 'IvcChampva::Vha1010d2027' which doesn't exist
      expect(described_class.get_form_class('vha_10_10d_2027')).to eq(IvcChampva::VHA1010d2027)
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
    let(:form_data) { { 'test' => 'data', 'form_number' => 'TEST-FORM' } }

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(false)
      end

      it 'creates an instance of the base form class' do
        result = described_class.create_form_instance('test_base_form', form_data, nil)
        expect(result).to be_a(IvcChampva::TestBaseForm)
        expect(result.form_id).to eq('test_base_form')
        expect(result.data).to eq(form_data)
      end

      it 'returns a form instance with proper Hash metadata that supports dig' do
        result = described_class.create_form_instance('test_base_form', form_data, nil)
        metadata = result.metadata

        expect(metadata).to be_a(Hash)
        expect(metadata).to respond_to(:dig)
        expect(metadata.dig('uuid')).to be_present
        expect(metadata.dig('docType')).to eq('TEST-FORM')
      end
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(true)
      end

      it 'creates an instance of the versioned form class' do
        result = described_class.create_form_instance('test_base_form', form_data, nil)
        expect(result).to be_a(IvcChampva::TestVersionedForm)
        expect(result.form_id).to eq('test_versioned_form')
      end

      it 'returns versioned form with proper Hash metadata' do
        result = described_class.create_form_instance('test_base_form', form_data, nil)
        metadata = result.metadata

        expect(metadata).to be_a(Hash)
        expect(metadata).to respond_to(:dig)
        expect(metadata.dig('formExpiration')).to eq('12/31/2025')
      end
    end

    context 'when called with an already-resolved form ID (controller bug scenario)' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(true)
      end

      it 'handles double-resolution gracefully and still creates correct form instance' do
        # Simulate the controller bug: passing already-resolved form_id to create_form_instance
        # resolve_form_version will return the input as-is since it's not a base form ID
        # but get_form_class should still work thanks to the VHA capitalization fix
        result = described_class.create_form_instance('test_versioned_form', form_data, nil)

        expect(result).to be_a(IvcChampva::TestVersionedForm)
        expect(result.metadata).to be_a(Hash)
        expect(result.metadata).to respond_to(:dig)
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
        allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with('test_form_2024_enabled', anything).and_return(false)
        allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(true)

        result = described_class.resolve_form_version('test_base_form', nil)
        expect(result).to eq('test_versioned_form')
      end

      it 'prefers earlier version if both are enabled' do
        allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with('test_form_2024_enabled', anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(true)

        result = described_class.resolve_form_version('test_base_form', nil)
        expect(result).to eq('test_form_2024')
      end
    end

    context 'when form mapping changes over time' do
      it 'handles new forms being added to existing versions' do
        # Simulate adding a new form to the system
        new_versions = described_class::FORM_VERSIONS.dup
        new_versions['new_form'] = { current: 'new_form', '2025' => 'new_form_2025' }

        stub_const('IvcChampva::FormVersionManager::FORM_VERSIONS', new_versions)
        allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(true)

        result = described_class.resolve_form_version('new_form', nil)
        expect(result).to eq('new_form') # Falls back to current since no feature flag enabled
      end
    end
  end

  # Regression tests for the "String does not have #dig method" bug
  describe 'metadata generation compatibility' do
    let(:form_data) { { 'test' => 'data', 'form_number' => 'TEST-FORM' } }

    it 'creates form instances with Hash metadata that supports dig operations' do
      allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(true)
      allow(Flipper).to receive(:enabled?).with('test_versioned_form_enabled', anything).and_return(true)

      # Test both base and versioned forms
      %w[test_base_form test_versioned_form].each do |form_id|
        form = described_class.create_form_instance(form_id, form_data, nil)
        metadata = form.metadata

        expect(metadata).to be_a(Hash), "Expected Hash for #{form_id}, got #{metadata.class}"
        expect(metadata).to respond_to(:dig), "Expected metadata to respond to #dig for #{form_id}"

        # Verify dig actually works (this is where the original bug would manifest)
        expect { metadata.dig('uuid') }.not_to raise_error
        expect { metadata.dig('docType') }.not_to raise_error
      end
    end
  end
end
