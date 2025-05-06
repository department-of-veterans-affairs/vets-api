# frozen_string_literal: true

require 'efolder/service'

def stub_efolder_index_documents
  let(:list_documents_res) do
    [{ document_id: '{73CD7B28-F695-4337-BBC1-2443A913ACF6}',
       doc_type: '702',
       type_description: 'Disability Benefits Questionnaire (DBQ) - Veteran Provided',
       received_at: Date.new(2024, 9, 13) },
     { document_id: '{EF7BF420-7E49-4FA9-B14C-CE5F6225F615}',
       doc_type: '45',
       type_description: 'Military Personnel Record',
       received_at: Date.new(2024, 9, 13) }]
  end

  before do
    expect(efolder_service).to receive(:list_documents).and_return(
      list_documents_res
    )
  end
end

def stub_efolder_show_document
  let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
  let(:content) { File.read('spec/fixtures/files/error_message.txt') }

  before do
    expect(efolder_service).to receive(:get_document).with(document_id).and_return(content)
  end
end

private

def efolder_service
  efolder_service = double
  expect(Efolder::Service).to receive(:new).and_return(efolder_service)
  efolder_service
end
