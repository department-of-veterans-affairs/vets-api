# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/tracked_item_content'

RSpec.describe BenefitsClaims::TrackedItemContent do
  describe 'SCHEMA_PATH' do
    it 'points to an existing schema file' do
      expect(File).to exist(described_class::SCHEMA_PATH)
    end

    it 'contains valid JSON' do
      schema_content = File.read(described_class::SCHEMA_PATH)
      expect { JSON.parse(schema_content) }.not_to raise_error
    end

    it 'is a valid JSON Schema' do
      schema = JSON.parse(File.read(described_class::SCHEMA_PATH))
      expect(schema).to have_key('$schema')
      expect(schema).to have_key('definitions')
      expect(schema['type']).to eq('object')
    end
  end

  describe 'SCHEMA' do
    it 'successfully loads the schema in normal conditions' do
      expect(described_class::SCHEMA).not_to be_nil
      expect(described_class::SCHEMA).to be_a(Hash)
      expect(described_class::SCHEMA).to be_frozen
      expect(described_class::SCHEMA).not_to have_key('$schema')
    end
  end

  describe 'CONTENT_PATH' do
    it 'points to an existing content file' do
      expect(File).to exist(described_class::CONTENT_PATH)
    end

    it 'contains valid JSON' do
      content = File.read(described_class::CONTENT_PATH)

      expect { JSON.parse(content) }.not_to raise_error
    end
  end

  describe 'CONTENT' do
    it 'successfully loads content in normal conditions' do
      expect(described_class::CONTENT).to be_a(Hash)
      expect(described_class::CONTENT).to be_frozen
      expect(described_class::CONTENT).not_to be_empty
    end

    it 'contains entries that all pass schema validation' do
      errors = described_class.validate_all_entries
      expect(errors).to be_empty, lambda {
        errors.map { |name, errs| "#{name}: #{errs.join(', ')}" }.join("\n")
      }
    end
  end

  describe '.validate_all_entries' do
    it 'returns errors for schema when SCHEMA is nil' do
      stub_const("#{described_class}::SCHEMA", nil)
      errors = described_class.validate_all_entries
      expect(errors).to eq({ 'schema' => ['Schema failed to load'] })
    end

    it 'returns empty hash when CONTENT is empty' do
      stub_const("#{described_class}::CONTENT", {}.freeze)

      errors = described_class.validate_all_entries

      expect(errors).to be_empty
    end

    it 'returns no errors when all entries are valid' do
      errors = described_class.validate_all_entries
      expect(errors).to be_empty
    end
  end

  describe '.validate_entry' do
    it 'returns error message when SCHEMA is nil' do
      stub_const("#{described_class}::SCHEMA", nil)
      errors = described_class.validate_entry({})
      expect(errors).to eq(['Schema failed to load'])
    end

    valid_entries = {
      'empty entry (all fields optional)' => {},
      'minimal entry with just friendlyName' => {
        friendlyName: 'Test item'
      },
      'full entry with all fields' => {
        friendlyName: 'Test item',
        shortDescription: 'A test tracked item',
        activityDescription: 'Test activity',
        supportAliases: ['Alias 1'],
        canUploadFile: true,
        noActionNeeded: false,
        isDBQ: false,
        isProperNoun: false,
        isSensitive: false,
        noProvidePrefix: false,
        longDescription: {
          blocks: [
            { type: 'paragraph', content: 'This is a simple paragraph.' },
            { type: 'paragraph',
              content: ['Text with ', { type: 'bold', content: 'bold text' }, ' and ',
                        { type: 'link', text: 'a link', href: 'https://va.gov' }] },
            { type: 'list', style: 'bullet',
              items: ['First item', ['Second item with ', { type: 'italic', content: 'italic' }]] }
          ]
        },
        nextSteps: {
          blocks: [
            { type: 'paragraph', content: 'Call us at ' },
            { type: 'paragraph', content: [{ type: 'telephone', contact: '8008271000' }] }
          ]
        }
      },
      'nested inline elements (bold containing link)' => {
        longDescription: {
          blocks: [{ type: 'paragraph',
                     content: [{ type: 'bold',
                                 content: ['bold with ', { type: 'link', text: 'nested link', href: '/path' }] }] }]
        }
      },
      'TTY telephone' => {
        nextSteps: { blocks: [{ type: 'paragraph', content: [{ type: 'telephone', contact: '711', tty: true }] }] }
      },
      'link style options (external and active)' => {
        longDescription: {
          blocks: [{ type: 'paragraph',
                     content: [{ type: 'link', text: 'External', href: 'https://example.com', style: 'external' },
                               { type: 'link', text: 'Active', href: '/active', style: 'active', testId: 'my-link' }] }]
        }
      },
      'numbered list' => {
        longDescription: { blocks: [{ type: 'list', style: 'numbered', items: ['Step 1', 'Step 2', 'Step 3'] }] }
      },
      'lineBreak blocks' => {
        longDescription: { blocks: [{ type: 'paragraph', content: 'Before break' }, { type: 'lineBreak' },
                                    { type: 'paragraph', content: 'After break' }] }
      },
      'inline lineBreak' => {
        longDescription: { blocks: [{ type: 'paragraph', content: ['Line 1', { type: 'lineBreak' }, 'Line 2'] }] }
      },
      'complex entry matching evidenceDictionary complexity' => {
        friendlyName: 'Test complex item',
        shortDescription: 'Test short description for complex item',
        activityDescription: 'Test activity description',
        supportAliases: ['Test Alias 1', 'Test Alias 2'],
        canUploadFile: true,
        longDescription: {
          blocks: [
            { type: 'paragraph', content: 'Test introductory paragraph with context.' },
            { type: 'paragraph', content: 'Test paragraph prompting a list:' },
            {
              type: 'list',
              style: 'numbered',
              items: [
                'Test numbered item 1 with parenthetical (like this).',
                'Test numbered item 2.',
                'Test numbered item 3.',
                'Test numbered item 4 with more detail.',
                'Test numbered item 5.',
                'Test numbered item 6 with a question?'
              ]
            },
            { type: 'paragraph', content: [
              'Test paragraph with ',
              { type: 'bold', content: 'bold text in the middle' },
              '. More text after.'
            ] },
            { type: 'paragraph', content: 'Test paragraph introducing bullet list:' },
            {
              type: 'list',
              style: 'bullet',
              items: [
                'Test bullet item 1',
                'Test bullet item 2 with details',
                ['Test bullet item 3 with ', { type: 'italic', content: 'italic text' }, ' inline'],
                ['Test bullet item 4 with ', { type: 'bold', content: 'bold text' }, ' inline']
              ]
            },
            { type: 'paragraph', content: 'Test paragraph before quoted text:' },
            { type: 'paragraph', content: [{ type: 'italic', content: 'Test quoted or emphasized text in italics.' }] }
          ]
        },
        nextSteps: {
          blocks: [
            { type: 'paragraph', content: [
              'Test paragraph with ',
              { type: 'bold', content: 'Test Form Name' },
              ' reference.'
            ] },
            { type: 'paragraph', content: [
              'Test paragraph with line break and link.',
              { type: 'lineBreak' },
              { type: 'link', text: 'Test Active Link', href: '/test/path/', style: 'active', testId: 'test-link-id' }
            ] },
            { type: 'paragraph', content: [
              'Test paragraph with phone ',
              { type: 'telephone', contact: '8005551234' },
              ' (',
              { type: 'telephone', contact: '711', tty: true },
              ') inline.'
            ] },
            { type: 'lineBreak' },
            { type: 'paragraph', content: [
              'Test paragraph with external link.',
              { type: 'lineBreak' },
              { type: 'link', text: 'Test External Link (opens in new tab)', href: 'https://example.com/external/', style: 'external' }
            ] },
            { type: 'paragraph', content: [
              'Test paragraph with ',
              { type: 'link', text: 'default link', href: '/test/default/' },
              ' and ',
              { type: 'link', text: 'active link', href: '/test/active/', style: 'active' },
              ' together.'
            ] }
          ]
        }
      }
    }.freeze

    invalid_entries = {
      'unknown properties' => { unknownField: 'value' },
      'invalid block type' => { longDescription: { blocks: [{ type: 'invalid_type', content: 'text' }] } },
      'invalid list style' => { longDescription: { blocks: [{ type: 'list', style: 'invalid', items: [] }] } },
      'invalid link style' => { longDescription: { blocks: [{ type: 'paragraph',
                                                              content: [{ type: 'link', text: 'Bad', href: '/path',
                                                                          style: 'invalid_style' }] }] } },
      'additional properties in block' => { longDescription: { blocks: [{ type: 'paragraph', content: 'text',
                                                                          extraField: 'bad' }] } },
      'wrong type for boolean field' => { isDBQ: 'yes' },
      'wrong type for supportAliases' => { supportAliases: 'not-an-array' }
    }.freeze

    context 'with valid entries' do
      valid_entries.each do |description, entry|
        it "validates #{description}" do
          errors = described_class.validate_entry(entry)
          expect(errors).to be_empty, -> { "Expected no errors but got: #{errors.join(', ')}" }
        end
      end
    end

    context 'with invalid entries' do
      invalid_entries.each do |description, entry|
        it "rejects #{description}" do
          errors = described_class.validate_entry(entry)
          expect(errors).not_to be_empty
        end
      end
    end
  end

  # rubocop:disable Rails/DynamicFindBy
  describe '.find_by_display_name' do
    it 'returns nil for non-existent display name' do
      result = described_class.find_by_display_name('Non-existent Item')
      expect(result).to be_nil
    end

    it 'returns nil when CONTENT is empty' do
      stub_const("#{described_class}::CONTENT", {}.freeze)

      result = described_class.find_by_display_name('21-4142/21-4142a')

      expect(result).to be_nil
    end

    it 'returns content merged with defaults for existing display name' do
      skip 'CONTENT is empty' if described_class::CONTENT.empty?

      display_name = described_class::CONTENT.keys.first
      result = described_class.find_by_display_name(display_name)

      # Verify defaults are applied
      described_class::DEFAULTS.each_key do |key|
        expect(result).to have_key(key)
      end

      # Verify entry values override defaults
      described_class::CONTENT[display_name].each do |key, value|
        expect(result[key]).to eq(value)
      end
    end

    it 'applies default values for missing fields' do
      skip 'CONTENT is empty' if described_class::CONTENT.empty?

      display_name = described_class::CONTENT.keys.first
      entry = described_class::CONTENT[display_name]
      result = described_class.find_by_display_name(display_name)

      # Fields not in entry should have default values
      (described_class::DEFAULTS.keys - entry.keys).each do |key|
        expect(result[key]).to eq(described_class::DEFAULTS[key])
      end
    end

    context 'with radiation exposure entry' do
      it 'returns radiation exposure content with correct attributes' do
        result = described_class.find_by_display_name('Radiation-tell us how you were exposed')

        expect(result).not_to be_nil
        expect(result[:friendlyName]).to eq('Radiation exposure information')
        expect(result[:shortDescription]).to include('radiation exposure')
        expect(result[:supportAliases]).to include('Radiation-tell us how you were exposed')
        expect(result[:canUploadFile]).to be true
        expect(result[:isSensitive]).to be true
        expect(result[:longDescription]).to have_key(:blocks)
        expect(result[:nextSteps]).to have_key(:blocks)
      end
    end
  end
  # rubocop:enable Rails/DynamicFindBy
end
