# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::PdfStamper do
  let(:data) { JSON.parse(File.read("modules/simple_forms_api/spec/fixtures/form_json/#{test_payload}.json")) }
  let(:form) { "SimpleFormsApi::#{test_payload.titleize.gsub(' ', '')}".constantize.new(data) }

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

  describe '.verified_stamp' do
    subject(:verified_stamp) { described_class.verified_stamp('template_path') { double } }

    before { allow(File).to receive(:size).and_return(orig_size, stamped_size) }

    describe 'when verifying a stamp' do
      let(:orig_size) { 10_000 }

      context 'when the stamped file size is larger than the original' do
        let(:stamped_size) { orig_size + 1 }

        it 'succeeds' do
          expect { verified_stamp }.not_to raise_error
        end
      end

      context 'when the stamped file size is the same as the original' do
        let(:stamped_size) { orig_size }

        it 'raises an error message' do
          expect { verified_stamp }.to raise_error('An error occurred while verifying stamp.')
        end
      end

      context 'when the stamped file size is less than the original' do
        let(:stamped_size) { orig_size - 1 }

        it 'raises an error message' do
          expect { verified_stamp }.to raise_error('An error occurred while verifying stamp.')
        end
      end
    end
  end
end
