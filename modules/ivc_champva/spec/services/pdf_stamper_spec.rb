# frozen_string_literal: true

require 'rails_helper'
require IvcChampva::Engine.root.join('spec', 'spec_helper.rb')

describe IvcChampva::PdfStamper do
  let(:data) { JSON.parse(File.read("modules/ivc_champva/spec/fixtures/form_json/#{test_payload}.json")) }
  let(:form) { "IvcChampva::#{test_payload.titleize.gsub(' ', '')}".constantize.new(data) }
  let(:path) { 'tmp/stuff.json' }

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
          expect { verify }.to raise_error(
            'An error occurred while verifying stamp: The PDF remained unchanged upon stamping.'
          )
        end
      end

      context 'when the stamped file size is less than the original' do
        let(:stamped_size) { orig_size - 1 }

        it 'raises an error message' do
          expect { verify }.to raise_error(
            'An error occurred while verifying stamp: The PDF remained unchanged upon stamping.'
          )
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
        expect { verified_multistamp }.to raise_error('The provided stamp content was empty.')
      end
    end
  end
end
