# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PoaDocumentService do
  subject { described_class.new }

  let(:poa) do
    create(:power_of_attorney,
           id: '581128c6-ad08-4b1e-8b82-c3640e829fb3',
           auth_headers: {
             'va_eauth_firstName' => 'John',
             'va_eauth_lastName' => 'Doe',
             'va_eauth_pid' => 'VET123'
           })
  end
  let(:pdf_path) { '/path/to/nonexistent/document.pdf' }
  let(:doc_type) { 'L075' }
  let(:action) { 'post' }

  describe '#create_upload' do
    context 'when PDF file does not exist' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(pdf_path).and_return(false)
      end

      it 'raises Errno::ENOENT with the pdf_path' do
        expect do
          subject.create_upload(poa:, pdf_path:, doc_type:, action:)
        end.to raise_error(Errno::ENOENT, /#{Regexp.escape(pdf_path)}/)
      end

      it 'logs the error with poa_id and file path' do
        allow(ClaimsApi::Logger).to receive(:log)

        expect(ClaimsApi::Logger).to receive(:log).with(
          'Poa_Document_service',
          detail: include(pdf_path, "poa_id: #{poa.id}")
        ).at_least(:once)

        expect do
          subject.create_upload(poa:, pdf_path:, doc_type:, action:)
        end.to raise_error(Errno::ENOENT)
      end
    end

    context 'when PDF file exists' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(pdf_path).and_return(true)
        allow_any_instance_of(described_class).to receive(
          :generate_upload_body
        ).and_return(
          { parameters: { some: 'params' }, file: 'file_data' }
        )
        allow_any_instance_of(ClaimsApi::BD).to receive(:upload_document).and_return({ success: true })
      end

      it 'does not raise an error' do
        expect do
          subject.create_upload(
            poa:, pdf_path:, doc_type:, action:
          )
        end.not_to raise_error
      end

      it 'calls upload_document on BD client' do
        expect_any_instance_of(ClaimsApi::BD).to receive(:upload_document).with(
          identifier: poa.id, doc_type_name: 'POA', body: anything
        )

        subject.create_upload(poa:, pdf_path:, doc_type:, action:)
      end
    end
  end

  describe '#build_name_for_file' do
    context 'when not a dependent filing' do
      let(:poa) do
        create(:power_of_attorney,
               auth_headers: {
                 'va_eauth_firstName' => 'John', 'va_eauth_lastName' => 'Doe'
               })
      end

      it 'returns the compacted veteran name' do
        allow_any_instance_of(described_class).to receive(:dependent_filing?).with(poa).and_return(false)

        expect_any_instance_of(described_class).to receive(:compact_name_for_file).with('John', 'Doe').and_call_original

        subject.send(:build_name_for_file, poa)
      end
    end

    context 'when filing for a dependent' do
      let(:poa) do
        create(:power_of_attorney,
               auth_headers: {
                 'va_eauth_firstName' => 'John',
                 'va_eauth_lastName' => 'Doe',
                 'dependent' => {
                   'first_name' => 'Jane',
                   'last_name' => 'Doe'
                 }
               })
      end

      it 'returns the compacted dependent name' do
        allow_any_instance_of(described_class).to receive(:dependent_filing?).with(poa).and_return(true)

        expect_any_instance_of(described_class).to receive(:compact_name_for_file).with('Jane', 'Doe').and_call_original

        subject.send(:build_name_for_file, poa)
      end
    end
  end
end
