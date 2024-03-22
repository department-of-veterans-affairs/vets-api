# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::PdfStamper do
  let(:data) { JSON.parse(File.read("modules/simple_forms_api/spec/fixtures/form_json/#{test_payload}.json")) }
  let(:form) { "SimpleFormsApi::#{test_payload.titleize.gsub(' ', '')}".constantize.new(data) }

  describe 'pdf_stamping' do
    subject(:stamp) { SimpleFormsApi::PdfStamper.send(stamp_method, generated_form_path, form) }

    before do
      allow(Common::FileHelpers).to receive(:random_file_path).and_return('fake/stamp_path')
      allow(Common::FileHelpers).to receive(:delete_file_if_exists)
    end

    context 'when generating stamped file' do
      [
        %w[stamp214142 vba_21_4142],
        %w[stamp2110210 vba_21_10210],
        %w[stamp21p0847 vba_21p_0847]
      ].each do |stamp_method, test_payload|
        context "when #{stamp_method} receives #{test_payload} payload" do
          let(:test_payload) { test_payload }
          let(:stamp_method) { stamp_method }
          let(:generated_form_path) { 'fake/generated_form_path' }

          it 'raises an error' do
            expect { stamp }.to raise_error(StandardError, 'An error occurred while verifying stamp.')
          end
        end
      end
    end
  end
end
