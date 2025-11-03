# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::VBA21p601 do
  # Attachment specs, adopted from modules/simple_forms_api/spec/models/vba_40_0247_spec.rb
  describe '#handle_attachments' do
    it 'writes merged pdf even if no attachments' do
      file_path = 'original-file-path'
      pdf = double('HexaPDF::Document', pages: [], write: true)
      allow(HexaPDF::Document).to receive(:open).with(file_path).and_return(pdf)
      expect(pdf).to receive(:write).with(file_path, optimize: true)
      described_class.new({}).handle_attachments(file_path)
    end

    it 'merges attachments if present' do
      file_path = 'original-file-path'
      attachment_path = 'attachment.pdf'
      pdf = double('HexaPDF::Document', pages: [], write: true, import: true)
      attachment_pdf = double('HexaPDF::Document', pages: [double('HexaPDF::Page')])
      allow(HexaPDF::Document).to receive(:open).with(file_path).and_return(pdf)
      allow(HexaPDF::Document).to receive(:open).with(attachment_path).and_return(attachment_pdf)
      allow_any_instance_of(SimpleFormsApi::VBA21p601).to receive(:get_attachments).and_return([attachment_path])
      expect(pdf).to receive(:import).at_least(:once)
      expect(pdf).to receive(:write).with(file_path, optimize: true)
      described_class.new({}).handle_attachments(file_path)
    end

    it 'handles supporting document attachments' do
      file_path = 'original-file-path'
      pdf = double('HexaPDF::Document', pages: [], write: true, import: true)
      attachment_pdf = double('HexaPDF::Document', pages: [double('HexaPDF::Page')])
      attachment = double('PersistentAttachment', to_pdf: 'pdf_path')
      allow(PersistentAttachment).to receive(:where).with(guid: ['abc']).and_return([attachment])
      allow(HexaPDF::Document).to receive(:open).with(file_path).and_return(pdf)
      allow(HexaPDF::Document).to receive(:open).with('pdf_path').and_return(attachment_pdf)
      allow_any_instance_of(SimpleFormsApi::VBA21p601).to receive(:get_attachments).and_return(['pdf_path'])
      expect(pdf).to receive(:import).at_least(:once)
      expect(pdf).to receive(:write).with(file_path, optimize: true)
      data = {
        'veteran_supporting_documents' => [
          { 'confirmation_code' => 'abc' }
        ]
      }
      described_class.new(data).handle_attachments(file_path)
    end
  end

  describe 'private #get_attachments' do
    it 'returns attachments for supporting documents' do
      data = {
        'veteran_supporting_documents' => [
          { 'confirmation_code' => 'abc' }
        ]
      }
      attachment = double('PersistentAttachment', to_pdf: 'pdf_path')
      allow(PersistentAttachment).to receive(:where).with(guid: ['abc']).and_return([attachment])
      expect(described_class.new(data).send(:get_attachments)).to include('pdf_path')
    end

    it 'returns empty array if no attachments' do
      expect(described_class.new({}).send(:get_attachments)).to eq []
    end
  end
end
