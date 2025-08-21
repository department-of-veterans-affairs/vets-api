# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::VBA4010007 do
  let(:sample_data) do
    {
      'form_number' => '40-10007',
      'application' => {
        'claimant' => {
          'relationship_to_vet' => '1',
          'name' => { 'first' => 'John', 'last' => 'Doe' },
          'ssn' => '123-45-6789',
          'email' => 'john.doe@example.com',
          'phone_number' => '555-123-4567',
          'address' => { 'postal_code' => '12345-6789' }
        },
        'veteran' => {
          'current_name' => { 'first' => 'Jane', 'last' => 'Smith' },
          'ssn' => '987-65-4321',
          'service_records' => [{ 'branch' => 'Army' }]
        },
        'applicant' => { 'applicant_relationship_to_claimant' => 'Self' },
        'preneed_attachments' => [{ 'confirmation_code' => 'abc123' }]
      }
    }
  end

  let(:form) { described_class.new(sample_data) }

  describe '#not_veteran?' do
    it 'returns false for veteran' do
      expect(form.not_veteran?(sample_data)).to be false
    end

    it 'returns true for non-veteran' do
      data = sample_data.dup
      data['application']['claimant']['relationship_to_vet'] = '2'
      expect(form.not_veteran?(data)).to be true
    end
  end

  describe '#veteran_or_claimant_first_name' do
    it 'returns claimant name when veteran' do
      expect(form.veteran_or_claimant_first_name(sample_data)).to eq 'John'
    end
  end

  describe '#veteran_or_claimant_file_number' do
    it 'returns empty string when nil' do
      data = sample_data.dup
      data['application']['claimant']['ssn'] = nil
      expect(described_class.new(data).veteran_or_claimant_file_number(data)).to eq ''
    end
  end

  describe '#metadata' do
    it 'returns metadata hash' do
      result = form.metadata
      expect(result['fileNumber']).to eq '123456789'
      expect(result['docType']).to eq '40-10007'
    end
  end

  describe '#zip_code_is_us_based' do
    it 'returns true' do
      expect(form.zip_code_is_us_based).to be true
    end
  end

  describe '#service' do
    it 'returns service record value' do
      expect(form.service(0, 'branch', nil)).to eq 'Army'
    end

    it 'returns empty string when nil' do
      expect(form.service(5, 'branch', nil)).to eq ''
    end
  end

  describe '#find_cemetery_by_id' do
    before do
      allow(File).to receive(:read).and_return('{"data":[{"attributes":{"cemetery_id":"001","name":"Test Cemetery"}}]}')
    end

    it 'finds cemetery' do
      expect(form.find_cemetery_by_id('001')).to eq 'Test Cemetery'
    end

    it 'returns not found message' do
      expect(form.find_cemetery_by_id('999')).to eq 'Cemetery not found.'
    end
  end

  describe '#format_date' do
    it 'formats date' do
      expect(form.format_date('2023-12-25')).to eq '12/25/2023'
    end

    it 'returns empty string' do
      expect(form.format_date('')).to eq ''
    end
  end

  describe '#get_relationship_to_vet' do
    it 'returns relationship' do
      expect(form.get_relationship_to_vet('1')).to eq 'Is veteran'
    end
  end

  describe '#create_attachment_page' do
    it 'creates attachment' do
      mock_attachment = double('VBA4010007Attachment')
      allow(SimpleFormsApi::VBA4010007Attachment).to receive(:new).and_return(mock_attachment)
      allow(mock_attachment).to receive(:create)
      
      form.create_attachment_page('test.pdf')
      expect(mock_attachment).to have_received(:create)
    end
  end

  describe '#handle_attachments' do
  it 'processes attachments when they exist' do
      main_pdf = double('HexaPDF::Document')
      attachment_page_pdf = double('HexaPDF::Document')
      attachment_pdf = double('HexaPDF::Document')
      page = double('HexaPDF::Page')
      
      allow(form).to receive(:get_attachments).and_return(['attachment1.pdf'])
      allow(form).to receive(:create_attachment_page)
      allow(HexaPDF::Document).to receive(:open).with('test.pdf').and_return(main_pdf)
      allow(HexaPDF::Document).to receive(:open).with('attachment_page.pdf').and_return(attachment_page_pdf)
      allow(HexaPDF::Document).to receive(:open).with('attachment1.pdf').and_return(attachment_pdf)
      
      allow(attachment_page_pdf).to receive(:pages).and_return([page])
      allow(attachment_pdf).to receive(:pages).and_return([page])
      allow(main_pdf).to receive(:pages).and_return([page])
      allow(main_pdf).to receive(:import).and_return(page)
      allow(main_pdf).to receive(:write)
      allow(FileUtils).to receive(:rm_f)

      form.handle_attachments('test.pdf')
      
      expect(HexaPDF::Document).to have_received(:open).with('attachment1.pdf')
    end
     it 'handles attachment error' do
      main_pdf = double('HexaPDF::Document')
      attachment_page_pdf = double('HexaPDF::Document')
      page = double('HexaPDF::Page')
      
      allow(form).to receive(:get_attachments).and_return(['bad_file.pdf'])
      allow(form).to receive(:create_attachment_page)
      allow(HexaPDF::Document).to receive(:open).with('test.pdf').and_return(main_pdf)
      allow(HexaPDF::Document).to receive(:open).with('attachment_page.pdf').and_return(attachment_page_pdf)
      allow(HexaPDF::Document).to receive(:open).with('bad_file.pdf').and_raise(StandardError.new('test error'))
      
      allow(attachment_page_pdf).to receive(:pages).and_return([page])
      allow(main_pdf).to receive(:pages).and_return([page])
      allow(main_pdf).to receive(:import).and_return(page)
      allow(main_pdf).to receive(:write)
      allow(FileUtils).to receive(:rm_f)
      allow(Rails.logger).to receive(:error)

      expect { form.handle_attachments('test.pdf') }.to raise_error(StandardError)
      expect(Rails.logger).to have_received(:error)
    end
  end

  describe '#track_user_identity' do
    it 'tracks identity' do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:info)
      
      form.track_user_identity('CONF123')
      expect(StatsD).to have_received(:increment)
    end
  end

  describe '#submission_date_stamps' do
    it 'returns empty array' do
      expect(form.submission_date_stamps('timestamp')).to eq []
    end
  end

  describe '#desired_stamps' do
    it 'returns empty array' do
      expect(form.desired_stamps).to eq []
    end
  end

  describe 'private methods' do
    it 'extracts words to remove' do
      expect(form.words_to_remove).to be_an Array
    end

    it 'gets attachments' do
      allow(PersistentAttachment).to receive(:where).and_return([])
      expect(form.send(:get_attachments)).to eq []
    end
  end

  describe 'handle_attachments' do
    it 'saves the merged pdf' do
      original_pdf = double('HexaPDF::Document')
      combined_pdf = double('HexaPDF::Document')
      original_file_path = 'original-file-path'
      attachment_page_path = 'attachment_page.pdf'
      page = double('HexaPDF::Page')

      form = build(:vba4010007)

      allow(HexaPDF::Document).to receive(:open).with(original_file_path).and_return(original_pdf)
      allow(HexaPDF::Document).to receive(:open).with(attachment_page_path).and_return(combined_pdf)

      allow(combined_pdf).to receive(:pages).and_return([page])
      allow(original_pdf).to receive(:pages).and_return([page])

      allow(original_pdf).to receive(:import).with(page).and_return(page)

      allow(original_pdf).to receive(:write).with(original_file_path, optimize: true)

      allow(form).to receive(:create_attachment_page).with(attachment_page_path)

      form.handle_attachments(original_file_path)

      expect(HexaPDF::Document).to have_received(:open).with(original_file_path)
      expect(HexaPDF::Document).to have_received(:open).with(attachment_page_path)
      expect(original_pdf).to have_received(:write).with(original_file_path, optimize: true)
    end
  end

  describe '#notification_first_name' do
    context 'applicant is claimant' do
      let(:data) do
        {
          'application' => {
            'applicant' => {
              'applicant_relationship_to_claimant' => 'Self'
            },
            'claimant' => {
              'name' => {
                'first' => 'Claimant'
              }
            }
          }
        }
      end

      it 'returns the preparer first name' do
        expect(described_class.new(data).notification_first_name).to eq 'Claimant'
      end
    end

    context 'applicant is not claimant' do
      let(:data) do
        {
          'application' => {
            'applicant' => {
              'applicant_relationship_to_claimant' => 'Not Self',
              'name' => {
                'first' => 'Applicant'
              }
            }
          }
        }
      end

      it 'returns the applicant first name' do
        expect(described_class.new(data).notification_first_name).to eq 'Applicant'
      end
    end
  end

  describe '#notification_email_address' do
    let(:data) do
      {
        'application' => {
          'claimant' => {
            'email' => 'a@b.com'
          }
        }
      }
    end

    it 'returns the claimant email address' do
      expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
    end
  end
end
