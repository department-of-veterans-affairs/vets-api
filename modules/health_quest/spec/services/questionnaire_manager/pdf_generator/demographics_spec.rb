# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::PdfGenerator::Demographics do
  subject { described_class }

  let(:qr) do
    double(
      'QuestionnaireResponse',
      user_demographics_data: {
        'date_of_birth' => '05-05-1955',
        'first_name' => 'Foo',
        'last_name' => 'Bar',
        'home_address' => {
          'address_line1' => 'line one',
          'address_line2' => 'line two',
          'address_line3' => 'line three',
          'city' => 'my city',
          'state_code' => 'GA',
          'zip_code' => '55555'
        },
        'work_phone' => {
          'area_code' => '555',
          'phone_number' => '3334444'
        }
      }
    )
  end
  let(:composer) { HealthQuest::QuestionnaireManager::PdfGenerator::Composer }

  before do
    allow_any_instance_of(composer).to receive(:build_pdf).and_return('')
  end

  describe '.build' do
    it 'is an instance of Demographics' do
      expect(subject.build).to be_an_instance_of(described_class)
    end
  end

  describe 'attributes' do
    it 'responds to opts' do
      expect(subject.build.respond_to?(:opts)).to be(true)
    end

    it 'responds to composer' do
      expect(subject.build.respond_to?(:composer)).to be(true)
    end
  end

  describe '#draw' do
    before do
      allow_any_instance_of(described_class).to receive(:demographics_header).and_return('')
      allow_any_instance_of(described_class).to receive(:full_name).and_return('')
      allow_any_instance_of(described_class).to receive(:dob).and_return('')
      allow_any_instance_of(described_class).to receive(:gender).and_return('')
      allow_any_instance_of(described_class).to receive(:country).and_return('')
      allow_any_instance_of(described_class).to receive(:mailing_address).and_return('')
      allow_any_instance_of(described_class).to receive(:home_address).and_return('')
      allow_any_instance_of(described_class).to receive(:home_phone).and_return('')
      allow_any_instance_of(described_class).to receive(:mobile_phone).and_return('')
      allow_any_instance_of(described_class).to receive(:work_phone).and_return('')
    end

    it 'uses calls the appropriate methods' do
      expect_any_instance_of(described_class).to receive(:demographics_header).once
      expect_any_instance_of(described_class).to receive(:full_name).once
      expect_any_instance_of(described_class).to receive(:dob).once
      expect_any_instance_of(described_class).to receive(:gender).once
      expect_any_instance_of(described_class).to receive(:country).once
      expect_any_instance_of(described_class).to receive(:mailing_address).once
      expect_any_instance_of(described_class).to receive(:home_address).once
      expect_any_instance_of(described_class).to receive(:home_phone).once
      expect_any_instance_of(described_class).to receive(:mobile_phone).once
      expect_any_instance_of(described_class).to receive(:work_phone).once

      subject.build(opts: {}, composer: composer.synthesize).draw.to_s
    end
  end

  describe '#demographics_header' do
    it 'calls set_text twice' do
      expect_any_instance_of(Prawn::Document).to receive(:text_box).once

      subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).demographics_header
    end
  end

  describe '#full_name' do
    it 'calls set_text twice' do
      expect_any_instance_of(described_class).to receive(:set_text).twice

      subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).full_name
    end
  end

  describe '#dob' do
    it 'calls set_text twice' do
      expect_any_instance_of(described_class).to receive(:set_text).twice

      subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).dob
    end
  end

  describe '#gender' do
    it 'calls set_text twice' do
      expect_any_instance_of(described_class).to receive(:set_text).twice

      subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).gender
    end
  end

  describe '#country' do
    it 'calls set_text twice' do
      expect_any_instance_of(described_class).to receive(:set_text).twice

      subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).country
    end
  end

  describe '#mailing_address' do
    it 'calls set_text twice' do
      expect_any_instance_of(described_class).to receive(:set_text).twice

      subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).mailing_address
    end
  end

  describe '#home_address' do
    it 'calls set_text twice' do
      expect_any_instance_of(described_class).to receive(:set_text).twice

      subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).home_address
    end
  end

  describe '#home_phone' do
    it 'calls set_text twice' do
      expect_any_instance_of(described_class).to receive(:set_text).twice

      subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).home_phone
    end
  end

  describe '#mobile_phone' do
    it 'calls set_text twice' do
      expect_any_instance_of(described_class).to receive(:set_text).twice

      subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).mobile_phone
    end
  end

  describe '#work_phone' do
    it 'calls set_text twice' do
      expect_any_instance_of(described_class).to receive(:set_text).twice

      subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).work_phone
    end
  end

  describe '#set_text' do
    context 'when `key`' do
      it 'calls set_text with the right arguments' do
        expect_any_instance_of(Prawn::Document).to receive(:text_box)
          .with('Foo', { at: [30, 541.89], size: 12, style: :normal }).once

        subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).set_text('Foo', 300, 'key')
      end
    end

    context 'when `value`' do
      it 'calls set_text with the correct arguments' do
        expect_any_instance_of(Prawn::Document).to receive(:text_box)
          .with('Foo', { at: [120, 541.89], size: 12, style: :medium }).once

        subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).set_text('Foo', 300, 'value')
      end
    end
  end

  describe '#formatted_dob' do
    it 'has a formatted_dob' do
      expect(subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).formatted_dob)
        .to eq('05/05/1955')
    end
  end

  describe '#formatted_name' do
    it 'has a formatted_name' do
      expect(subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).formatted_name)
        .to eq('Foo Bar')
    end
  end

  describe '#format_address' do
    it 'formats a given address' do
      demographics = subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize)

      expect(demographics.format_address(demographics.user_data['home_address']))
        .to eq('line one line two line three, my city, GA 55555')
    end
  end

  describe '#format_phone' do
    it 'formats a given phone' do
      demographics = subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize)

      expect(demographics.format_phone(demographics.user_data['work_phone']))
        .to eq('555-333-4444')
    end
  end

  describe '#user_data' do
    it 'returns user_data' do
      expect(subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).user_data)
        .to eq(qr.user_demographics_data)
    end
  end
end
