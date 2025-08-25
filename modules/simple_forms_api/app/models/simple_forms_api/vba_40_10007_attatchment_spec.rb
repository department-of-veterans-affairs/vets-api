# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::VBA4010007Attachment do
  let(:sample_data) do
    {
      'version' => '1.0',
      'application' => {
        'veteran' => {
          'gender' => 'Male',
          'race_comment' => 'Test comment',
          'place_of_birth' => 'Test City',
          'city_of_birth' => 'Birth City',
          'state_of_birth' => 'Birth State',
          'ethnicity' => 'isSpanishHispanicLatino',
          'email' => 'vet@example.com',
          'phone_number' => '555-1234',
          'military_status' => 'A',
          'current_name' => { 'maiden' => 'Smith' },
          'race' => {
            'is_american_indian_or_alaskan_native' => true,
            'is_asian' => false,
            'is_black_or_african_american' => true,
            'is_native_hawaiian_or_other_pacific_islander' => false,
            'is_white' => true,
            'na' => false,
            'is_other' => false
          },
          'service_records' => [
            {
              'service_branch' => 'AR',
              'discharge_type' => '1',
              'highest_rank' => 'E5',
              'highest_rank_description' => 'Sergeant'
            },
            {
              'service_branch' => 'AF',
              'discharge_type' => '2',
              'highest_rank' => 'O3',
              'highest_rank_description' => 'Captain'
            },
            {
              'service_branch' => 'NA',
              'discharge_type' => '3',
              'highest_rank' => 'E7',
              'highest_rank_description' => 'Chief'
            }
          ]
        },
        'claimant' => {
          'relationship_to_vet' => '2'
        }
      }
    }
  end

  let(:attachment) { described_class.new(file_path: 'test.pdf', data: sample_data) }

  describe '#initialize' do
    it 'sets file_path and data' do
      expect(attachment.file_path).to eq 'test.pdf'
      expect(attachment.data).to eq sample_data
    end
  end

  describe '#create' do
    let(:mock_pdf) { double('Prawn::Document') }

    before do
      allow(Prawn::Document).to receive(:generate).and_yield(mock_pdf)
      allow(mock_pdf).to receive(:text)
      allow(mock_pdf).to receive(:move_down)
    end

    it 'creates PDF with version data' do
      attachment.create
      expect(Prawn::Document).to have_received(:generate).with('test.pdf')
    end

    context 'without version' do
      let(:no_version_data) do
        data = sample_data.dup
        data.delete('version')
        data
      end

      it 'creates PDF without version-specific data' do
        no_version_attachment = described_class.new(file_path: 'test.pdf', data: no_version_data)
        no_version_attachment.create
        expect(Prawn::Document).to have_received(:generate).with('test.pdf')
      end
    end

    context 'with all race options selected' do
      let(:all_race_data) do
        data = sample_data.dup
        data['application']['veteran']['race'] = {
          'is_american_indian_or_alaskan_native' => true,
          'is_asian' => true,
          'is_black_or_african_american' => true,
          'is_native_hawaiian_or_other_pacific_islander' => true,
          'is_white' => true,
          'na' => true,
          'is_other' => true
        }
        data
      end

      it 'includes all race categories' do
        all_race_attachment = described_class.new(file_path: 'test.pdf', data: all_race_data)
        all_race_attachment.create
        expect(Prawn::Document).to have_received(:generate)
      end
    end
  end

  describe 'private methods' do
    describe '#get_gender' do
      it 'returns gender labels' do
        expect(attachment.send(:get_gender, 'Male')).to eq 'Male'
        expect(attachment.send(:get_gender, 'Female')).to eq 'Female'
        expect(attachment.send(:get_gender, 'na')).to eq 'Prefer not to answer'
        expect(attachment.send(:get_gender, 'unknown')).to be_nil
      end
    end

    describe '#get_service_label' do
      it 'returns service labels' do
        expect(attachment.send(:get_service_label, 'AR')).to eq 'U.S. Army'
        expect(attachment.send(:get_service_label, 'AF')).to eq 'U.S. Air Force'
        expect(attachment.send(:get_service_label, 'NA')).to eq 'U.S. Navy'
        expect(attachment.send(:get_service_label, 'unknown')).to be_nil
      end
    end

    describe '#get_discharge_label' do
      it 'returns discharge labels' do
        expect(attachment.send(:get_discharge_label, '1')).to eq 'Honorable'
        expect(attachment.send(:get_discharge_label, '2')).to eq 'General'
        expect(attachment.send(:get_discharge_label, '7')).to eq 'Other'
        expect(attachment.send(:get_discharge_label, 'unknown')).to be_nil
      end
    end

    describe '#get_ethnicity_labels' do
      it 'returns ethnicity labels' do
        expect(attachment.send(:get_ethnicity_labels, 'isSpanishHispanicLatino')).to eq 'Hispanic or Latino'
        expect(attachment.send(:get_ethnicity_labels, 'notSpanishHispanicLatino')).to eq 'Not Hispanic or Latino'
        expect(attachment.send(:get_ethnicity_labels, 'unknown')).to eq 'Unknown'
        expect(attachment.send(:get_ethnicity_labels, 'na')).to eq 'Prefer not to answer'
      end
    end

    describe '#get_military_status' do
      it 'returns military status labels' do
        expect(attachment.send(:get_military_status, 'A')).to eq 'Active duty'
        expect(attachment.send(:get_military_status, 'V')).to eq 'Veteran'
        expect(attachment.send(:get_military_status, 'R')).to eq 'Retired'
        expect(attachment.send(:get_military_status, 'D')).to eq 'Died on active duty'
      end
    end
  end

  describe 'constants' do
    it 'defines GENDER constant' do
      expect(described_class::GENDER).to be_a Hash
      expect(described_class::GENDER['Male']).to eq 'Male'
    end

    it 'defines SERVICE_LABELS constant' do
      expect(described_class::SERVICE_LABELS).to be_a Hash
      expect(described_class::SERVICE_LABELS['AR']).to eq 'U.S. Army'
    end

    it 'defines DISCHARGE_TYPE constant' do
      expect(described_class::DISCHARGE_TYPE).to be_a Hash
      expect(described_class::DISCHARGE_TYPE['1']).to eq 'Honorable'
    end

    it 'defines ETHNICITY_VALUES constant' do
      expect(described_class::ETHNICITY_VALUES).to be_a Hash
      expect(described_class::ETHNICITY_VALUES['isSpanishHispanicLatino']).to eq 'Hispanic or Latino'
    end

    it 'defines MILITARY_STATUS constant' do
      expect(described_class::MILITARY_STATUS).to be_a Hash
      expect(described_class::MILITARY_STATUS['A']).to eq 'Active duty'
    end
  end
end
