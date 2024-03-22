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

    %w[21-4142 21-10210 21p-0847].each do |form_number|
      context "when generating a stamped form #{form_number}" do
        let(:stamp_method) { "stamp#{form_number.gsub('-', '')}" }
        let(:test_payload) { "vba_#{form_number.gsub('-', '_')}" }
        let(:generated_form_path) { 'fake/generated_form_path' }

        it 'raises an error' do
          expect { stamp }.to raise_error(StandardError, 'An error occurred while verifying stamp.')
        end
      end
    end
  end
end
