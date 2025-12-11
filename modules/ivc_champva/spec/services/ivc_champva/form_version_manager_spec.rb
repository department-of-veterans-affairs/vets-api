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
        @form_id = 'vha_12_34x'
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
        @form_id = 'vha_12_34x_versioned'
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
    stub_const('IvcChampva::VHA1234x', test_base_form)
    stub_const('IvcChampva::VHA1234xVersioned', test_versioned_form)

    # Stub the form version configuration constants with test values
    stub_const('IvcChampva::FormVersionManager::FORM_VERSIONS', {
                 'vha_12_34x' => {
                   current: 'vha_12_34x',
                   '2025' => 'vha_12_34x_versioned'
                 }
               })

    stub_const('IvcChampva::FormVersionManager::FORM_VERSION_FLAGS', {
                 'vha_12_34x_versioned' => 'vha_12_34x_versioned_enabled'
               })

    stub_const('IvcChampva::FormVersionManager::LEGACY_MAPPING', {
                 'vha_12_34x_versioned' => 'vha_12_34x'
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
          allow(Flipper).to receive(:enabled?).with('vha_12_34x_versioned_enabled', anything).and_return(false)
        end

        it 'returns the current version' do
          result = described_class.resolve_form_version('vha_12_34x', nil)
          expect(result).to eq('vha_12_34x')
        end
      end

      context 'and feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with('vha_12_34x_versioned_enabled', anything).and_return(true)
        end

        it 'returns the versioned form ID' do
          result = described_class.resolve_form_version('vha_12_34x', nil)
          expect(result).to eq('vha_12_34x_versioned')
        end

        it 'passes the current_user to Flipper' do
          user = double('User')
          expect(Flipper).to receive(:enabled?).with('vha_12_34x_versioned_enabled', user).and_return(true)
          described_class.resolve_form_version('vha_12_34x', user)
        end
      end
    end
  end

  describe '.get_legacy_form_id' do
    it 'returns the legacy form ID for versioned forms' do
      result = described_class.get_legacy_form_id('vha_12_34x_versioned')
      expect(result).to eq('vha_12_34x')
    end

    it 'returns the same form ID for non-versioned forms' do
      result = described_class.get_legacy_form_id('vha_12_34x')
      expect(result).to eq('vha_12_34x')
    end
  end

  describe '.get_form_class' do
    it 'resolves VHA-prefixed form IDs to correct class names' do
      expect(described_class.get_form_class('vha_12_34x')).to eq(IvcChampva::VHA1234x)
      expect(described_class.get_form_class('vha_12_34x_versioned')).to eq(IvcChampva::VHA1234xVersioned)
    end
  end

  describe '.versioned_form?' do
    it 'returns true for forms with legacy mapping' do
      result = described_class.versioned_form?('vha_12_34x_versioned')
      expect(result).to be true
    end

    it 'returns false for forms without legacy mapping' do
      result = described_class.versioned_form?('vha_12_34x')
      expect(result).to be false
    end
  end

  describe '.create_form_instance' do
    let(:form_data) { { 'test' => 'data', 'form_number' => 'TEST-FORM' } }

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with('vha_12_34x_versioned_enabled', anything).and_return(false)
      end

      it 'creates an instance of the base form class' do
        result = described_class.create_form_instance('vha_12_34x', form_data, nil)
        expect(result).to be_a(IvcChampva::VHA1234x)
        expect(result.form_id).to eq('vha_12_34x')
        expect(result.data).to eq(form_data)
      end

      it 'returns a form instance with proper Hash metadata that supports dig' do
        result = described_class.create_form_instance('vha_12_34x', form_data, nil)
        metadata = result.metadata

        expect(metadata).to be_a(Hash)
        expect(metadata).to respond_to(:dig)
        expect(metadata['uuid']).to be_present
        expect(metadata['docType']).to eq('TEST-FORM')
      end
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with('vha_12_34x_versioned_enabled', anything).and_return(true)
      end

      it 'creates an instance of the versioned form class' do
        result = described_class.create_form_instance('vha_12_34x', form_data, nil)
        expect(result).to be_a(IvcChampva::VHA1234xVersioned)
        expect(result.form_id).to eq('vha_12_34x_versioned')
      end

      it 'returns versioned form with proper Hash metadata' do
        result = described_class.create_form_instance('vha_12_34x', form_data, nil)
        metadata = result.metadata

        expect(metadata).to be_a(Hash)
        expect(metadata).to respond_to(:dig)
        expect(metadata['formExpiration']).to eq('12/31/2025')
      end
    end

    context 'when called with an already-resolved form ID (controller bug scenario)' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with('vha_12_34x_versioned_enabled', anything).and_return(true)
      end

      it 'handles double-resolution gracefully and still creates correct form instance' do
        # Simulate the controller bug: passing already-resolved form_id to create_form_instance
        # resolve_form_version will return the input as-is since it's not a base form ID
        # but get_form_class should still work thanks to the VHA capitalization fix
        result = described_class.create_form_instance('vha_12_34x_versioned', form_data, nil)

        expect(result).to be_a(IvcChampva::VHA1234xVersioned)
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
                     'vha_12_34x' => {
                       current: 'vha_12_34x',
                       '2024' => 'vha_test_2024',
                       '2025' => 'vha_12_34x_versioned'
                     }
                   })

        stub_const('IvcChampva::FormVersionManager::FORM_VERSION_FLAGS', {
                     'vha_test_2024' => 'vha_test_2024_enabled',
                     'vha_12_34x_versioned' => 'vha_12_34x_versioned_enabled'
                   })
      end

      it 'uses the first enabled version in iteration order' do
        allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with('vha_test_2024_enabled', anything).and_return(false)
        allow(Flipper).to receive(:enabled?).with('vha_12_34x_versioned_enabled', anything).and_return(true)

        result = described_class.resolve_form_version('vha_12_34x', nil)
        expect(result).to eq('vha_12_34x_versioned')
      end

      it 'prefers earlier version if both are enabled' do
        allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with('vha_test_2024_enabled', anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with('vha_12_34x_versioned_enabled', anything).and_return(true)

        result = described_class.resolve_form_version('vha_12_34x', nil)
        expect(result).to eq('vha_test_2024')
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
      allow(Flipper).to receive(:enabled?).with('vha_12_34x_versioned_enabled', anything).and_return(true)

      # Test both base and versioned forms
      %w[vha_12_34x vha_12_34x_versioned].each do |form_id|
        form = described_class.create_form_instance(form_id, form_data, nil)
        metadata = form.metadata

        expect(metadata).to be_a(Hash), "Expected Hash for #{form_id}, got #{metadata.class}"
        expect(metadata).to respond_to(:dig), "Expected metadata to respond to #dig for #{form_id}"

        # Verify dig actually works (this is where the original bug would manifest)
        expect { metadata['uuid'] }.not_to raise_error
        expect { metadata['docType'] }.not_to raise_error
      end
    end
  end
end
