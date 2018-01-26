# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::SupportingDocumentationAttachment, type: :model do
  describe '.combine_documents' do
    it 'should combine the documents to one pdf file' do
      attachment1 = create(:supporting_documentation_attachment)
      attachment2 = create(:supporting_documentation_attachment,
                           file_path: 'spec/fixtures/files/va.gif',
                           file_type: 'image/gif')

      file_path = described_class.combine_documents([attachment1.guid, attachment2.guid])

      expect(PDF::Reader.new(file_path).page_count).to eq(2)

      File.delete(file_path)
    end
  end

  describe '#set_file_data!' do
    context 'with a non pdf file' do
      it 'should convert the file to pdf' do
        attachment = create(:supporting_documentation_attachment,
                            file_path: 'spec/fixtures/files/va.gif',
                            file_type: 'image/gif')

        expect(MimeMagic.by_magic(attachment.get_file.read).type).to eq('application/pdf')
      end
    end

    context 'with a pdf file' do
      it 'should stay pdf' do
        allow_any_instance_of(described_class).to receive(:convert_to_pdf) do
          raise
        end

        create(
          :supporting_documentation_attachment,
          file_path: 'spec/fixtures/files/doctors-note.pdf',
          file_type: 'application/pdf'
        )
      end
    end
  end
end
