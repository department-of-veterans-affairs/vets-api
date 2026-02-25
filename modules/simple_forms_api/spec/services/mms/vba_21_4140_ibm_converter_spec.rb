# spec/services/mss/form4140_ibm_converter_spec.rb
require 'rails_helper'


require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe SimpleFormsApi::Mms::VBA214140IbmConverter do
  let(:fixture_file) { 'vba_21_4140.json' }
  let(:fixture_path) do
    Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', fixture_file)
  end
  let(:data) { JSON.parse(File.read(fixture_path)) }
  let(:form) { SimpleFormsApi::VBA214140.new(data) }

  let(:ibm_fixture_file) { 'vba_21_4140_ibm_payload.json' }
  let(:ibm_fixture_path) do
    Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', ibm_fixture_file)
  end
  let(:ibm_payload) { JSON.parse(File.read(ibm_fixture_path)) } 

  describe '.convert' do
    subject(:payload) { described_class.convert(form) }

    it 'converts a parsed form to the keys and formats expected by IBM' do
      ibm_payload['DATE_SIGNED'] = Date.today.strftime('%m%d%Y')

      expect(payload).to eq(ibm_payload)
    end

    it 'normalizes SSN' do
      expect(payload['VETERAN_SSN']).to eq('547901234')
    end

    it 'formats DOB as MMDDYYYY' do
      expect(payload['VETERAN_DOB']).to eq('02271979')
    end

    it 'downcases email' do
      expect(payload['EMAIL']).to eq('test@example.com')
    end

    it 'includes employer info' do
      expect(payload['EMPLOYER_NAME_ADDRESS']).to eq('Test Employer\\n1234 Executive Ave\\nMetropolis, CA 90210\\nUnited States of America')
    end

    it 'includes full name correctly' do
      expect(payload['VETERAN_FULL_NAME']).to eq('Rumpelstilts T Mephistopheles-Rei')
    end

    it 'truncates first name correctly' do
      expect(payload['VETERAN_FIRST_NAME']).to eq('Rumpelstilts')
    end

    it 'sets DATE_SIGNED as the current date' do
      expect(payload['DATE_SIGNED']).to eq(Date.today.strftime('%m%d%Y'))
    end
  end
end