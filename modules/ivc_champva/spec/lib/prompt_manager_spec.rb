# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::PromptManager do
  describe '.get_prompt' do
    let(:default_prompt_path) do
      Rails.root.join('modules', 'ivc_champva', 'config', 'prompts', 'default_doc_validation.txt')
    end
    let(:doc_validation_template_path) do
      Rails.root.join('modules', 'ivc_champva', 'config', 'prompts', 'doc_validation.txt')
    end
    let(:default_prompt_content) { File.read(default_prompt_path).strip }
    let(:doc_validation_template) { File.read(doc_validation_template_path).strip }

    before do
      allow(described_class).to receive(:read_prompt).with('default_doc_validation').and_return(default_prompt_content)
      allow(described_class).to receive(:read_prompt).with('doc_validation').and_return(doc_validation_template)
      allow(Rails.logger).to receive(:info)
    end

    context 'when document type is nil' do
      it 'returns the default prompt' do
        result = described_class.get_prompt(nil)
        expect(result).to eq(default_prompt_content)
      end

      it 'logs that it is using the default prompt' do
        expect(Rails.logger).to receive(:info).with('IvcChampva::PromptManager using default prompt for ')
        described_class.get_prompt(nil)
      end
    end

    context 'when document type is not supported' do
      it 'returns the default prompt' do
        result = described_class.get_prompt('unknown type')
        expect(result).to eq(default_prompt_content)
      end

      it 'logs that it is using the default prompt' do
        expect(Rails.logger).to receive(:info).with('IvcChampva::PromptManager using default prompt for unknown type')
        described_class.get_prompt('unknown type')
      end
    end

    context 'when document type is EOB' do
      it 'returns the EOB prompt with correct replacements' do
        result = described_class.get_prompt('EOB')

        # Should replace %DOCUMENT_TYPE% with EOB definition
        expect(result).to include('EOB (Explanation of Benefits)')
        expect(result).not_to include('%DOCUMENT_TYPE%')

        # Should replace %EXPECTED_FIELDS% with formatted EOB fields
        expect(result).to include('Date of Service')
        expect(result).to include('Provider Name')
        expect(result).to include('Provider NPI (10-digit)')
        expect(result).to include('Services Paid For (CPT/HCPCS code or description)')
        expect(result).to include('Amount Paid by Insurance')
        expect(result).not_to include('%EXPECTED_FIELDS%')
      end

      it 'logs that it generated a prompt for EOB' do
        expect(Rails.logger).to receive(:info).with('IvcChampva::PromptManager generated prompt for EOB')
        described_class.get_prompt('EOB')
      end
    end

    context 'when document type is medical invoice' do
      it 'returns the medical invoice prompt with correct replacements' do
        result = described_class.get_prompt('medical invoice')

        # Should replace %DOCUMENT_TYPE% with medical invoice definition
        expect(result).to include('MedicalBill (medical bill/invoice)')
        expect(result).not_to include('%DOCUMENT_TYPE%')

        # Should include medical invoice specific fields
        expect(result).to include('Beneficiary Full Name')
        expect(result).to include('Provider Medical Title')
        expect(result).to include('Diagnosis (DX) Codes')
        expect(result).not_to include('%EXPECTED_FIELDS%')
      end

      it 'logs that it generated a prompt for medical invoice' do
        expect(Rails.logger).to receive(:info).with('IvcChampva::PromptManager generated prompt for medical invoice')
        described_class.get_prompt('medical invoice')
      end
    end

    context 'when document type is pharmacy invoice' do
      it 'returns the pharmacy invoice prompt with correct replacements' do
        result = described_class.get_prompt('pharmacy invoice')

        # Should replace %DOCUMENT_TYPE% with pharmacy invoice definition
        expect(result).to include('PharmacyBill (pharmacy bill/invoice)')
        expect(result).not_to include('%DOCUMENT_TYPE%')

        # Should include pharmacy invoice specific fields
        expect(result).to include('Pharmacy Name')
        expect(result).to include('Medication Name')
        expect(result).to include('National Drug Code (NDC, 11-digit)')
        expect(result).not_to include('%EXPECTED_FIELDS%')
      end

      it 'logs that it generated a prompt for pharmacy invoice' do
        expect(Rails.logger).to receive(:info).with('IvcChampva::PromptManager generated prompt for pharmacy invoice')
        described_class.get_prompt('pharmacy invoice')
      end
    end
  end
end
