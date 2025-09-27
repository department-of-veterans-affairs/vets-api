# frozen_string_literal: true

require 'rails_helper'
require 'pdf-reader'

RSpec.describe SimpleFormsApi::VBA4010007Attachment do
  subject { described_class.new(file_path:, data:) }

  let(:file_path) { Rails.root.join('tmp', 'test_attachment.pdf').to_s }
  let(:data) do
    {
      'application' => {
        'veteran' => {
          'gender' => 'Male',
          'race_comment' => 'No comment',
          'place_of_birth' => 'Springfield, IL',
          'city_of_birth' => 'Springfield',
          'state_of_birth' => 'IL',
          'service_records' => [
            {
              'service_branch' => 'AR',
              'discharge_type' => '1',
              'highest_rank' => 'Sergeant',
              'highest_rank_description' => 'SGT'
            },
            {
              'service_branch' => 'NA',
              'discharge_type' => '2',
              'highest_rank' => 'Lieutenant',
              'highest_rank_description' => 'LT'
            },
            {
              'service_branch' => 'MC',
              'discharge_type' => '3',
              'highest_rank' => 'Captain',
              'highest_rank_description' => 'CPT'
            }
          ],
          'ethnicity' => 'isSpanishHispanicLatino',
          'email' => 'vet@example.com',
          'phone_number' => '555-555-5555',
          'current_name' => { 'maiden' => 'Smith' },
          'military_status' => 'V',
          'race' => {
            'is_american_indian_or_alaskan_native' => true,
            'is_asian' => false,
            'is_black_or_african_american' => true,
            'is_native_hawaiian_or_other_pacific_islander' => false,
            'is_white' => true,
            'na' => false,
            'is_other' => false
          }
        },
        'claimant' => {
          'relationship_to_vet' => 'Spouse'
        }
      },
      'version' => true
    }
  end

  describe '#initialize' do
    it 'sets file_path and data' do
      expect(subject.file_path).to eq(file_path)
      expect(subject.data).to eq(data)
    end
  end

  describe '#create' do
    it 'generates a PDF file at the given path with version true' do
      subject.create
      expect(File).to exist(file_path)
      File.delete(file_path)
    end

    it 'includes expected veteran and claimant info in the PDF' do
      subject.create
      reader = PDF::Reader.new(file_path)
      text = reader.pages.map(&:text).join(' ')
      expect(text).to include('Springfield')
      expect(text).to include('SGT')
      expect(text).to include('Hispanic or Latino')
      File.delete(file_path)
    end
  end

  describe 'private methods' do
    it 'returns correct gender label' do
      expect(subject.send(:get_gender, 'Male')).to eq('Male')
      expect(subject.send(:get_gender, 'na')).to eq('Prefer not to answer')
    end

    it 'returns correct service label' do
      expect(subject.send(:get_service_label, 'AR')).to eq('U.S. Army')
    end

    it 'returns correct discharge label' do
      expect(subject.send(:get_discharge_label, '1')).to eq('Honorable')
    end

    it 'returns correct ethnicity label' do
      expect(subject.send(:get_ethnicity_labels, 'isSpanishHispanicLatino')).to eq('Hispanic or Latino')
    end

    it 'returns correct military status label' do
      expect(subject.send(:get_military_status, 'V')).to eq('Veteran')
    end
  end

  describe '#create else branch coverage' do
    subject { described_class.new(file_path:, data:) }

    let(:file_path) { Rails.root.join('tmp', 'test_attachment.pdf').to_s }
    let(:data) do
      {
        'application' => {
          'veteran' => {
            'service_records' => [
              { 'service_branch' => 'AR', 'discharge_type' => '1', 'highest_rank' => 'Sergeant' },
              { 'service_branch' => 'NA', 'discharge_type' => '2', 'highest_rank' => 'Lieutenant' },
              { 'service_branch' => 'MC', 'discharge_type' => '3', 'highest_rank' => 'Captain' }
            ]
          }
        }
        # no 'version' key
      }
    end

    it 'generates a PDF file at the given path with version missing' do
      subject.create
      expect(File).to exist(file_path)
      File.delete(file_path)
    end

    it 'includes expected service info in the PDF' do
      subject.create
      reader = PDF::Reader.new(file_path)
      text = reader.pages.map(&:text).join(' ')
      expect(text).to include('Sergeant')
      expect(text).to include('Lieutenant')
      expect(text).to include('Captain')
      File.delete(file_path)
    end
  end
end
