# frozen_string_literal: true

require 'rails_helper'

require 'pdf_info'

def set_last_exit_code(code)
  `exit #{code}`
end

describe PdfInfo::Metadata do
  let(:result) do
    <<EOF
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
Page size:      612 x 792 pts (letter)
Page rot:       0
File size:      1099807 bytes
Optimized:      no
PDF version:    1.3"
EOF
  end

  before(:each) do
    allow_any_instance_of(described_class).to receive(:`).and_return(result)
    set_last_exit_code(0)
  end

  describe '::read' do
    context "when passed a string" do
      it 'should shell out with the string as the file path' do
        expect_any_instance_of(described_class).to receive(:`).with('pdfinfo /tmp/file.pdf').and_return(result)
        described_class.read('/tmp/file.pdf')
      end
    end

    context 'when passed a file' do
      it 'should shell out with the file object path' do
        file = double(File)
        allow(file).to receive(:path).and_return('/tmp/file.pdf')
        expect_any_instance_of(described_class).to receive(:`).with('pdfinfo /tmp/file.pdf').and_return(result)
        described_class.read(file)
      end
    end

    context 'when the command errors' do
      it 'should raise a PdfInfo::MetadataReadError' do
        set_last_exit_code(1)
        expect{ described_class.read('/tmp/file.pdf') }.to raise_error(PdfInfo::MetadataReadError)
      end
    end
  end

  describe '#[]' do
    it 'should fetch a key from the parsed result' do
      metadata = described_class.read('/tmp/file.pdf')
      expect(metadata['Title']).to be_nil
      expect(metadata['Pages']).to eq('4')
      expect(metadata['Encrypted']).to eq('no')
    end
  end

  describe '#pages' do
    it 'should return pages as an int' do
      metadata = described_class.read('/tmp/file.pdf')
      expect(metadata.pages).to eq(4)
    end
  end

  describe '#encrypted?' do
    it 'should return encryption as a boolean' do
      metadata = described_class.read('/tmp/file.pdf')
      expect(metadata.encrypted?).to be false
    end

    context 'when the document is encrypted' do
      let(:result) do
        <<EOF
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
EOF
      end

      it 'should return encryption as a boolean' do
        metadata = described_class.read('/tmp/file.pdf')
        expect(metadata.encrypted?).to be true
      end
    end
  end
end
