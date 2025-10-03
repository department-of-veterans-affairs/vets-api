# frozen_string_literal: true

require 'rails_helper'
require 'zip'

RSpec.describe TravelPay::DocReader do
  let(:rejection_letter_path) { File.join(__dir__, '../fixtures/rejection-letter-test.docx') }
  let(:partial_payment_letter_path) { File.join(__dir__, '../fixtures/partial-payment-letter-test.docx') }
  let(:missing_heading_letter_path) { File.join(__dir__, '../fixtures/missing-heading-letter-test.docx') }
  let(:missing_decision_reason_letter_path) do
    File.join(__dir__, '../fixtures/missing-decision-reason-letter-test.docx')
  end

  let(:rejection_letter_buffer) { File.read(rejection_letter_path) }
  let(:partial_payment_letter_buffer) { File.read(partial_payment_letter_path) }
  let(:missing_heading_letter_buffer) { File.read(missing_heading_letter_path) }
  let(:missing_decision_reason_letter_buffer) { File.read(missing_decision_reason_letter_path) }

  let(:rejection_letter_reader) { described_class.new(rejection_letter_buffer) }
  let(:partial_payment_letter_reader) { described_class.new(partial_payment_letter_buffer) }
  let(:missing_heading_letter_reader) { described_class.new(missing_heading_letter_buffer) }
  let(:missing_decision_reason_letter_reader) { described_class.new(missing_decision_reason_letter_buffer) }

  describe '#initialize' do
    it 'initializes with a buffer and reads the docx' do
      expect { rejection_letter_reader }.not_to raise_error
    end

    context 'when buffer is invalid' do
      let(:invalid_buffer) { 'invalid zip data' }

      it 'raises an error for invalid DOCX file' do
        expect { described_class.new(invalid_buffer) }.to raise_error(/Error reading DOCX file/)
      end
    end
  end

  describe '#denial_reasons' do
    it 'returns denial reason text when heading and pattern match' do
      result = rejection_letter_reader.denial_reasons
      expect(result).to include('Authority 38 CFR 70.10')
      expect(result).to include('Authority 38 CFR 70.4')
    end

    it 'returns nil when no denial reasons are found' do
      result = partial_payment_letter_reader.denial_reasons
      expect(result).to be_nil
    end

    context 'when heading is not found' do
      it 'returns nil and logs error when heading not found' do
        expect(Rails.logger).to receive(:error).with("DocReader: Heading not found for 'Denial Reason(s)'")
        result = missing_heading_letter_reader.denial_reasons
        expect(result).to be_nil
      end
    end
  end

  describe '#partial_payment_reasons' do
    it 'returns partial payment reason text when heading is found' do
      result = partial_payment_letter_reader.partial_payment_reasons
      expect(result).to include('Since you chose an appointment farther than your Preferred Facility')
    end

    it 'returns nil when no partial payment reasons are found' do
      result = rejection_letter_reader.partial_payment_reasons
      expect(result).to be_nil
    end
  end

  describe '#find_heading' do
    let(:reader) { rejection_letter_reader }

    it 'finds heading when exactly one match exists and is bold' do
      heading = reader.send(:find_heading, 'Denial Reason')
      expect(heading).not_to be_nil
      expect(heading.text).to include('Denial Reason')
    end

    context 'when multiple matches exist' do
      let(:doc_with_multiple_matches) do
        Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml['w'].document('xmlns:w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main') do
            xml['w'].body do
              xml['w'].p do
                xml['w'].r do
                  xml['w'].t 'Denial Reason'
                end
              end
              xml['w'].p do
                xml['w'].r do
                  xml['w'].t 'Another Denial Reason'
                end
              end
            end
          end
        end.to_xml
      end

      let(:buffer_with_multiple) do
        buffer = Zip::OutputStream.write_buffer do |out|
          out.put_next_entry('word/document.xml')
          out.write(doc_with_multiple_matches)
        end
        buffer.string
      end

      it 'returns nil when multiple matches exist' do
        reader = described_class.new(buffer_with_multiple)
        heading = reader.send(:find_heading, 'Denial Reason')
        expect(heading).to be_nil
      end
    end

    context 'when match is not bold' do
      let(:doc_with_non_bold_heading) do
        Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml['w'].document('xmlns:w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main') do
            xml['w'].body do
              xml['w'].p do
                xml['w'].r do
                  xml['w'].t 'Denial Reason'
                end
              end
            end
          end
        end.to_xml
      end

      let(:buffer_with_non_bold) do
        buffer = Zip::OutputStream.write_buffer do |out|
          out.put_next_entry('word/document.xml')
          out.write(doc_with_non_bold_heading)
        end
        buffer.string
      end

      it 'returns nil when heading is not bold' do
        reader = described_class.new(buffer_with_non_bold)
        heading = reader.send(:find_heading, 'Denial Reason')
        expect(heading).to be_nil
      end
    end
  end

  describe '#read_docx' do
    let(:reader) { rejection_letter_reader }

    it 'successfully reads valid DOCX buffer' do
      doc = reader.send(:read_docx, rejection_letter_buffer)
      expect(doc).to be_a(Nokogiri::XML::Document)
    end

    it 'raises error for invalid zip data' do
      expect { reader.send(:read_docx, 'invalid data') }.to raise_error(/Error reading DOCX file/)
    end
  end
end
