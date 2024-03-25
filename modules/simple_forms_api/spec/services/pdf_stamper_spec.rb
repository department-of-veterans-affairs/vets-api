# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::PdfStamper do
  let(:data) { JSON.parse(File.read("modules/simple_forms_api/spec/fixtures/form_json/#{test_payload}.json")) }
  let(:form) { "SimpleFormsApi::#{test_payload.titleize.gsub(' ', '')}".constantize.new(data) }
  let(:path) { 'tmp/stuff.json' }

  describe 'form-specific stamp methods' do
    subject(:stamp) { described_class.send(stamp_method, generated_form_path, form) }

    before do
      allow(Common::FileHelpers).to receive(:random_file_path).and_return('fake/stamp_path')
      allow(Common::FileHelpers).to receive(:delete_file_if_exists)
    end

    %w[21-4142 21-10210 21p-0847].each do |form_number|
      context "when generating a stamped file for form #{form_number}" do
        let(:stamp_method) { "stamp#{form_number.gsub('-', '')}" }
        let(:test_payload) { "vba_#{form_number.gsub('-', '_')}" }
        let(:generated_form_path) { 'fake/generated_form_path' }

        it 'raises an error' do
          expect { stamp }.to raise_error(StandardError, 'An error occurred while verifying stamp.')
        end
      end
    end
  end

  describe '.stamp107959f1' do
    subject(:stamp107959f1) { described_class.stamp107959f1(path, form) }

    before do
      allow(described_class).to receive(:stamp).and_return(true)
      allow(File).to receive(:size).and_return(1, 2)
    end

    context 'when statement_of_truth_signature is provided' do
      before { stamp107959f1 }

      let(:test_payload) { 'vha_10_7959f_1' }
      let(:signature) { form.data['statement_of_truth_signature'] }
      let(:stamps) { [[26, 82.5, signature]] }

      it 'calls stamp with correct desired_stamp' do
        expect(described_class).to have_received(:stamp).with(stamps, path, false)
      end
    end
  end

  describe '.stamp264555' do
    subject(:stamp264555) { described_class.stamp264555(path, form) }

    before do
      allow(described_class).to receive(:stamp).and_return(true)
      allow(File).to receive(:size).and_return(1, 2)
    end

    context 'when it is called with legitimate parameters' do
      before { stamp264555 }

      let(:test_payload) { 'vba_26_4555' }
      let(:stamps) { [] }

      it 'calls stamp correctly' do
        expect(described_class).to have_received(:stamp).with(stamps, path, false)
      end
    end
  end

  describe '.stamp210845' do
    subject(:stamp210845) { described_class.stamp210845(path, form) }

    before do
      allow(described_class).to receive(:multistamp).and_return(true)
      allow(File).to receive(:size).and_return(1, 2)
    end

    context 'when it is called with legitimate parameters' do
      before { stamp210845 }

      let(:test_payload) { 'vba_21_0845' }
      let(:signature) { form.data['statement_of_truth_signature'] }
      let(:page_config) do
        [
          { type: :new_page },
          { type: :new_page },
          { type: :text, position: [50, 240] }
        ]
      end

      it 'calls multistamp correctly' do
        expect(described_class).to have_received(:multistamp).with(path, signature, page_config)
      end
    end
  end

  describe '.verify' do
    subject(:verify) { described_class.verify('template_path') { double } }

    before { allow(File).to receive(:size).and_return(orig_size, stamped_size) }

    describe 'when verifying a stamp' do
      let(:orig_size) { 10_000 }

      context 'when the stamped file size is larger than the original' do
        let(:stamped_size) { orig_size + 1 }

        it 'succeeds' do
          expect { verify }.not_to raise_error
        end
      end

      context 'when the stamped file size is the same as the original' do
        let(:stamped_size) { orig_size }

        it 'raises an error message' do
          expect { verify }.to raise_error('An error occurred while verifying stamp.')
        end
      end

      context 'when the stamped file size is less than the original' do
        let(:stamped_size) { orig_size - 1 }

        it 'raises an error message' do
          expect { verify }.to raise_error('An error occurred while verifying stamp.')
        end
      end
    end
  end

  describe '.verified_multistamp' do
    subject(:verified_multistamp) { described_class.verified_multistamp(path, signature_text, config) }

    before { allow(described_class).to receive(:verify).and_return(true) }

    context 'when signature_text is blank' do
      let(:path) { nil }
      let(:signature_text) { nil }
      let(:config) { nil }

      it 'raises an error' do
        expect { verified_multistamp }.to raise_error('Provided signature was empty')
      end
    end
  end
end
