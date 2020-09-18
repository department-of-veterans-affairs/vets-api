# frozen_string_literal: true

require 'debts/letter_downloader'

def stub_debt_letters(method)
  let!(:letter_downloader) do
    letter_downloader = double
    expect(Debts::LetterDownloader).to receive(:new).and_return(letter_downloader)
    letter_downloader
  end

  if method == :show
    let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
    let(:content) { File.read('spec/fixtures/files/error_message.txt') }

    before do
      expect(letter_downloader).to receive(:get_letter).with(document_id).and_return(content)
      expect(letter_downloader).to receive(:file_name).with(document_id).and_return('filename.pdf')
    end
  else
    let(:list_letters_res) { get_fixture('vbms/list_letters') }

    before do
      expect(letter_downloader).to receive(:list_letters).and_return(
        list_letters_res
      )
    end
  end
end
