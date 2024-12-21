# frozen_string_literal: true

require 'rails_helper'
require IvcChampva::Engine.root.join('spec', 'spec_helper.rb')

describe IvcChampva::PdfStamper do
  let(:data) { JSON.parse(File.read("modules/ivc_champva/spec/fixtures/form_json/#{test_payload}.json")) }
  let(:form) { "IvcChampva::#{test_payload.titleize.gsub(' ', '')}".constantize.new(data) }
  let(:path) { 'tmp/stuff.json' }

  describe '.stamp_signature' do
    subject(:stamp_signature) { described_class.stamp_signature(path, form) }

    before do
      allow(File).to receive(:size).and_return(1, 2)
    end

    context 'when no stamps are needed' do
      before do
        allow(described_class).to receive(:stamp).and_return(true)
        stamp_signature
      end

      let(:test_payload) { 'vha_10_7959c' }
      let(:stamps) { [] }

      it 'does not call :stamp' do
        expect(described_class).not_to have_received(:stamp)
      end
    end

    context 'when it is called with legitimate parameters' do
      before do
        allow(described_class).to receive(:multistamp).and_return(true)
        stamp_signature
      end

      let(:test_payload) { 'vha_10_10d' }
      let(:signature) { form.data['statement_of_truth_signature'] }
      let(:page_config) do
        [
          { type: :text, position: [40, 105] },
          { type: :new_page },
          { type: :new_page },
          { type: :new_page },
          { type: :new_page }
        ]
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
        expect do
          verified_multistamp
        end.to raise_error('An error occurred while verifying multistamp stamp: The provided stamp content was empty.')
      end
    end
  end
end
