# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::VBA4010007 do
  describe 'handle_attachments' do
    it 'saves the merged pdf' do
      original_pdf = double('HexaPDF::Document')
      combined_pdf = double('HexaPDF::Document')
      original_file_path = Rails.root.join('tmp', 'original-file-path').to_s
      attachment_page_path = Rails.root.join('tmp', 'attachment_page.pdf').to_s
      page = double('HexaPDF::Page')

      form = build(:vba4010007)

      allow(HexaPDF::Document).to receive(:open).with(original_file_path).and_return(original_pdf)
      # Accept both the full path and the relative path for attachment_page.pdf
      allow(HexaPDF::Document).to receive(:open).with(attachment_page_path).and_return(combined_pdf)
      allow(HexaPDF::Document).to receive(:open).with('attachment_page.pdf').and_return(combined_pdf)
      allow(combined_pdf).to receive(:pages).and_return([page])
      allow(original_pdf).to receive(:pages).and_return([page])
      allow(original_pdf).to receive(:import).with(page).and_return(page)
      allow(original_pdf).to receive(:write).with(original_file_path, optimize: true)
      allow(form).to receive(:create_attachment_page).with(anything)

      form.handle_attachments(original_file_path)

      expect(HexaPDF::Document).to have_received(:open).with(original_file_path)
      expect(HexaPDF::Document).to have_received(:open).with('attachment_page.pdf')
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

    context 'missing applicant and claimant names' do
      let(:data) { { 'application' => { 'applicant' => {}, 'claimant' => {} } } }

      it 'returns nil if names are missing' do
        expect(described_class.new(data).notification_first_name).to be_nil
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

    context 'missing email' do
      let(:data) { { 'application' => { 'claimant' => {} } } }

      it 'returns nil if email is missing' do
        expect(described_class.new(data).notification_email_address).to be_nil
      end
    end
  end

  describe '#not_veteran?' do
    it 'returns true when relationship is not 1 or veteran' do
      data = { 'application' => { 'claimant' => { 'relationship_to_vet' => '2' } } }
      expect(described_class.new(data).not_veteran?(data)).to be true
    end

    it 'returns false when relationship is 1' do
      data = { 'application' => { 'claimant' => { 'relationship_to_vet' => '1' } } }
      expect(described_class.new(data).not_veteran?(data)).to be false
    end

    it 'returns false when relationship is veteran' do
      data = { 'application' => { 'claimant' => { 'relationship_to_vet' => 'veteran' } } }
      expect(described_class.new(data).not_veteran?(data)).to be false
    end
  end

  describe '#dig_data' do
    let(:form_data) do
      {
        'application' => {
          'claimant' => { 'relationship_to_vet' => '2', 'foo' => 'bar' },
          'veteran' => { 'baz' => 'qux' }
        }
      }
    end

    it 'returns value from veteran path if not veteran' do
      expect(
        described_class.new(form_data).dig_data(form_data, %w[application veteran baz], %w[application claimant foo])
      ).to eq 'qux'
    end

    it 'returns value from claimant path if veteran' do
      form_data['application']['claimant']['relationship_to_vet'] = '1'
      expect(
        described_class.new(form_data).dig_data(form_data, %w[application veteran baz], %w[application claimant foo])
      ).to eq 'bar'
    end
  end

  describe '#veteran_or_claimant_first_name' do
    it 'returns veteran first name if not veteran' do
      data = {
        'application' => {
          'claimant' => { 'relationship_to_vet' => '2' },
          'veteran' => { 'current_name' => { 'first' => 'Vet' } }
        }
      }
      expect(described_class.new(data).veteran_or_claimant_first_name(data)).to eq 'Vet'
    end

    it 'returns claimant first name if veteran' do
      data = {
        'application' => {
          'claimant' => { 'relationship_to_vet' => '1', 'name' => { 'first' => 'Claimant' } },
          'veteran' => { 'current_name' => { 'first' => 'Vet' } }
        }
      }
      expect(described_class.new(data).veteran_or_claimant_first_name(data)).to eq 'Claimant'
    end
  end

  describe '#veteran_or_claimant_last_name' do
    it 'returns veteran last name if not veteran' do
      data = {
        'application' => {
          'claimant' => { 'relationship_to_vet' => '2' },
          'veteran' => { 'current_name' => { 'last' => 'VetLast' } }
        }
      }
      expect(described_class.new(data).veteran_or_claimant_last_name(data)).to eq 'VetLast'
    end

    it 'returns claimant last name if veteran' do
      data = {
        'application' => {
          'claimant' => { 'relationship_to_vet' => '1', 'name' => { 'last' => 'ClaimantLast' } },
          'veteran' => { 'current_name' => { 'last' => 'VetLast' } }
        }
      }
      expect(described_class.new(data).veteran_or_claimant_last_name(data)).to eq 'ClaimantLast'
    end
  end

  describe '#veteran_or_claimant_file_number' do
    it 'returns veteran ssn if not veteran' do
      data = {
        'application' => {
          'claimant' => { 'relationship_to_vet' => '2' },
          'veteran' => { 'ssn' => '123456789' }
        }
      }
      expect(described_class.new(data).veteran_or_claimant_file_number(data)).to eq '123456789'
    end

    it 'returns claimant ssn if veteran' do
      data = {
        'application' => {
          'claimant' => { 'relationship_to_vet' => '1', 'ssn' => '987654321' },
          'veteran' => { 'ssn' => '123456789' }
        }
      }
      expect(described_class.new(data).veteran_or_claimant_file_number(data)).to eq '987654321'
    end

    it 'returns empty string if ssn missing' do
      data = {
        'application' => {
          'claimant' => { 'relationship_to_vet' => '1' },
          'veteran' => {}
        }
      }
      expect(described_class.new(data).veteran_or_claimant_file_number(data)).to eq ''
    end
  end

  describe '#metadata' do
    it 'returns metadata hash' do
      data = {
        'application' => {
          'claimant' => {
            'relationship_to_vet' => '1',
            'address' => { 'postal_code' => '12345' },
            'name' => { 'first' => 'Claimant', 'last' => 'Last' },
            'ssn' => '987654321'
          },
          'veteran' => {
            'current_name' => { 'first' => 'Vet', 'last' => 'Last' },
            'ssn' => '123456789'
          }
        },
        'form_number' => '40-10007'
      }
      result = described_class.new(data).metadata
      expect(result['veteranFirstName']).to eq 'Claimant'
      expect(result['veteranLastName']).to eq 'Last'
      expect(result['fileNumber']).to eq '987654321'
      expect(result['zipCode']).to eq '12345'
      expect(result['source']).to eq 'VA Platform Digital Forms'
      expect(result['docType']).to eq '40-10007'
      expect(result['businessLine']).to eq 'NCA'
    end
  end

  describe '#zip_code_is_us_based' do
    it 'returns true' do
      expect(described_class.new({}).zip_code_is_us_based).to be true
    end
  end

  describe '#service' do
    let(:data) do
      {
        'application' => {
          'veteran' => {
            'service_records' => [
              { 'branch' => 'Army', 'date' => { 'start' => '2020-01-01' } }
            ]
          }
        }
      }
    end

    it 'returns field value as string' do
      expect(described_class.new(data).service(0, 'branch', nil)).to eq 'Army'
    end

    it 'returns date value as string' do
      expect(described_class.new(data).service(0, 'date', 'start')).to eq '2020-01-01'
    end

    it 'returns empty string if service_records missing' do
      expect(described_class.new({}).service(0, 'branch', nil)).to eq ''
    end

    it 'returns empty string if service_records[num] missing' do
      data = { 'application' => { 'veteran' => { 'service_records' => [] } } }
      expect(described_class.new(data).service(0, 'branch', nil)).to eq ''
    end
  end

  describe '#find_cemetery_by_id' do
    it 'returns cemetery name if found' do
      allow(File).to receive(:read).and_return(
        {
          'data' => [
            {
              'attributes' => {
                'cemetery_id' => '123',
                'name' => 'Test Cemetery'
              }
            }
          ]
        }.to_json
      )
      expect(
        described_class.new({}).find_cemetery_by_id('123')
      ).to eq 'Test Cemetery'
    end

    it 'returns not found if missing' do
      allow(File).to receive(:read).and_return({ 'data' => [] }.to_json)
      expect(described_class.new({}).find_cemetery_by_id('999')).to eq 'Cemetery not found.'
    end
  end

  describe '#words_to_remove' do
    it 'returns an array' do
      expect(described_class.new({}).words_to_remove).to be_a(Array)
    end
  end

  describe '#format_date' do
    it 'returns empty string if date is empty' do
      expect(described_class.new({}).format_date('')).to eq ''
    end

    it 'formats date string' do
      expect(described_class.new({}).format_date('2020-01-02')).to eq '01/02/2020'
    end
  end

  describe '#get_relationship_to_vet' do
    it 'returns correct relationship' do
      expect(described_class.new({}).get_relationship_to_vet('1')).to eq 'Is veteran'
      expect(described_class.new({}).get_relationship_to_vet('2')).to eq 'Spouse or surviving spouse'
      expect(described_class.new({}).get_relationship_to_vet('4')).to eq 'Other'
    end
  end

  describe '#track_user_identity' do
    it 'increments stats and logs info' do
      data = { 'application' => { 'claimant' => { 'relationship_to_vet' => '1' } } }
      form = described_class.new(data)
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:info)
      form.track_user_identity('abc123')
      expect(StatsD).to have_received(:increment).with(/api\.simple_forms_api\.40_10007\.Is veteran/)
      expect(Rails.logger).to have_received(:info).with(
        'Simple forms api - 40-10007 submission user identity',
        identity: 'Is veteran',
        confirmation_number: 'abc123'
      )
    end
  end

  describe '#submission_date_stamps' do
    it 'returns empty array' do
      expect(described_class.new({}).submission_date_stamps(nil)).to eq []
    end
  end

  describe '#desired_stamps' do
    it 'returns empty array' do
      expect(described_class.new({}).desired_stamps).to eq []
    end
  end

  describe '#get_attachments' do
    it 'returns attachments if preneed_attachments present' do
      data = {
        'application' => {
          'preneed_attachments' => [
            { 'confirmation_code' => 'abc' }
          ]
        }
      }
      attachment = double('PersistentAttachment', to_pdf: 'pdf_path')
      allow(PersistentAttachment).to receive(:where).with(guid: ['abc']).and_return([attachment])
      expect(described_class.new(data).send(:get_attachments)).to eq ['pdf_path']
    end

    it 'returns empty array if preneed_attachments missing' do
      data = { 'application' => {} }
      expect(described_class.new(data).send(:get_attachments)).to eq []
    end
  end

  describe 'edge cases' do
    it 'handles missing application key gracefully' do
      expect { described_class.new({}).notification_first_name }.not_to raise_error
      expect(described_class.new({}).notification_first_name).to be_nil
    end
  end
end
