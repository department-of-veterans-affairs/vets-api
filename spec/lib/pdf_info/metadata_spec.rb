# frozen_string_literal: true

require 'rails_helper'

require 'pdf_info'

describe PdfInfo::Metadata do
  let(:result) do
    <<~STDOUT
      Title:
      Subject:
      Author:
      Creator:
      Producer:
      CreationDate:
      Tagged:         no
      UserProperties: no
      Suspects:       no
      Form:           none
      JavaScript:     no
      Pages:          4
      Encrypted:      no
      Page    1 size: 612 x 792 pts (letter)
      Page    2 size: 400 x 500 pts (letter)
      Page rot:       0
      File size:      1099807 bytes
      Optimized:      no
      PDF version:    1.3"
    STDOUT
  end

  let(:good_exit) do
    wait_thr = double
    value = double
    allow(wait_thr).to receive(:value).and_return(value)
    allow(value).to receive_messages(success?: true, exitstatus: 0)
    wait_thr
  end

  let(:bad_exit) do
    wait_thr = double
    value = double
    allow(wait_thr).to receive(:value).and_return(value)
    allow(value).to receive_messages(success?: false, exitstatus: 1)
    wait_thr
  end

  before do
    allow(Open3).to receive(:popen2e).and_yield('', result, good_exit)
  end

  describe '::read' do
    context 'when passed a string' do
      it 'shells out with the string as the file path' do
        expect(Open3).to receive(:popen2e).with('pdfinfo', '-l', '-1', '/tmp/file.pdf').and_yield('', result, good_exit)
        described_class.read('/tmp/file.pdf')
      end
    end

    context 'when passed a file' do
      it 'shells out with the file object path' do
        file = double(File)
        allow(file).to receive(:path).and_return('/tmp/file.pdf')
        expect(Open3).to receive(:popen2e).with('pdfinfo', '-l', '-1', '/tmp/file.pdf').and_yield('', result, good_exit)
        described_class.read(file)
      end
    end

    context 'when the command errors' do
      it 'raises a PdfInfo::MetadataReadError' do
        expect(Open3).to receive(:popen2e).with('pdfinfo', '-l', '-1', '/tmp/file.pdf').and_yield('', result, bad_exit)
        expect { described_class.read('/tmp/file.pdf') }.to raise_error(PdfInfo::MetadataReadError, /pdfinfo exited/)
      end
    end
  end

  describe '#[]' do
    it 'fetches a key from the parsed result' do
      metadata = described_class.read('/tmp/file.pdf')
      expect(metadata['Title']).to be_nil
      expect(metadata['Pages']).to eq('4')
      expect(metadata['Encrypted']).to eq('no')
    end
  end

  describe '#pages' do
    it 'returns pages as an int' do
      metadata = described_class.read('/tmp/file.pdf')
      expect(metadata.pages).to eq(4)
    end
  end

  describe '#page_size' do
    it 'returns the page dimensions in points' do
      metadata = described_class.read('/tmp/file.pdf')
      expect(metadata.page_size).to eq({ width: 612, height: 792 })
    end
  end

  describe '#file_size' do
    it 'returns the file size in bytes' do
      metadata = described_class.read('/tmp/file.pdf')
      expect(metadata.file_size).to eq(1_099_807)
    end
  end

  describe '#encrypted?' do
    it 'returns encryption as a boolean' do
      metadata = described_class.read('/tmp/file.pdf')
      expect(metadata.encrypted?).to be false
    end

    context 'when the document has invalid characters' do
      let(:result) do
        bad_str = (100..1000).to_a.pack('c*').force_encoding('utf-8')
        <<~STDOUT
          Title:
          Subject:
          Keywords:
          Author:         CamScanner
          Producer:       intsig.com pdf producer
          ModDate:        #{bad_str}
          Tagged:         no
          UserProperties: no
          Suspects:       no
          Form:           none
          JavaScript:     no
          Pages:          1
          Encrypted:      no
          Page size:      595 x 842 pts (A4)
          Page rot:       0
          File size:      1411924 bytes
          Optimized:      no
          PDF version:    1.6
        STDOUT
      end

      describe '#pages' do
        it 'returns pages as an int' do
          metadata = described_class.read('/tmp/file.pdf')
          expect(metadata.pages).to eq(1)
        end
      end
    end

    context 'when the document is encrypted' do
      let(:result) do
        <<~STDOUT
          Title:
          Subject:
          Author:
          Creator:
          Producer:
          CreationDate:
          Tagged:         no
          UserProperties: no
          Suspects:       no
          Form:           none
          JavaScript:     no
          Pages:          4
          Encrypted:      yes
          Page size:      612 x 792 pts (letter)
          Page rot:       0
          File size:      1099807 bytes
          Optimized:      no
          PDF version:    1.3"
        STDOUT
      end

      it 'returns encryption as a boolean' do
        metadata = described_class.read('/tmp/file.pdf')
        expect(metadata.encrypted?).to be true
      end
    end

    context 'when the document has an oversized page' do
      let(:result) do
        <<~STDOUT
          Title:
          Subject:
          Author:
          Creator:
          Producer:
          CreationDate:
          Tagged:         no
          UserProperties: no
          Suspects:       no
          Form:           none
          JavaScript:     no
          Pages:          2
          Encrypted:      no
          Page    1 size: 612 x 792 pts (letter)
          Page    2 size: 1944 x 2952 pts (letter)
          Page rot:       0
          File size:      1099807 bytes
          Optimized:      no
          PDF version:    1.3"
        STDOUT
      end

      it "returns hash with oversized page and it's dimensions" do
        metadata = described_class.read('/tmp/file.pdf')
        expect(metadata.oversized_pages_inches(20, 30)).to eq([{ page_number: 2, width: 27.0, height: 41.0 }])
      end
    end
  end
end
