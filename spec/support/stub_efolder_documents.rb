# frozen_string_literal: true

def stub_efolder_documents(method)
  let!(:efolder_service) do
    efolder_service = double
    expect(Efolder::Service).to receive(:new).with(user.ssn).and_return(efolder_service)
    efolder_service
  end

  if method == :show
    let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
    let(:content) { File.read('spec/fixtures/files/error_message.txt') }

    before do
      expect(efolder_servicee).to receive(:get_document).with(document_id).and_return(content)
    end
  else
    let(:list_documents_res) { get_fixtures('vbms/list_letters') }

    before do
      expect(letter_downloader).to receive(:list_documents).and_return(
        list_documents_res
      )
    end
  end
end
