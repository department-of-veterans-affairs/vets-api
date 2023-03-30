# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::PdfGenerator::AppointmentInfo do
  subject { described_class }

  let(:qr) do
    double(
      'QuestionnaireResponse',
      created_at: DateTime.parse('2001-02-03T04:05:06'),
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
  let(:appt) do
    double(
      'Appointment',
      resource: double('Resource', start: '2020-11-18T08:00:00Z')
    )
  end
  let(:location) do
    double('Location', resource: double('Resource', name: 'Foo'))
  end
  let(:org) do
    double('Org', resource: double('Resource', name: 'Bar'))
  end
  let(:composer) { HealthQuest::QuestionnaireManager::PdfGenerator::Composer }

  before do
    allow_any_instance_of(composer).to receive(:build_pdf).and_return('')
  end

  describe '.build' do
    it 'is an instance of AppointmentInfo' do
      expect(subject.build).to be_an_instance_of(described_class)
    end
  end

  describe 'attributes' do
    it 'responds to opts' do
      expect(subject.build.respond_to?(:opts)).to eq(true)
    end

    it 'responds to composer' do
      expect(subject.build.respond_to?(:composer)).to eq(true)
    end
  end

  describe '#draw' do
    before do
      allow_any_instance_of(described_class).to receive(:provider_text).and_return('')
      allow_any_instance_of(described_class).to receive(:appointment_date).and_return('')
      allow_any_instance_of(described_class).to receive(:appointment_time).and_return('')
      allow_any_instance_of(described_class).to receive(:appointment_destination).and_return('')
    end

    it 'uses calls the appropriate methods' do
      expect_any_instance_of(described_class).to receive(:provider_text).once
      expect_any_instance_of(described_class).to receive(:appointment_date).once
      expect_any_instance_of(described_class).to receive(:appointment_time).once
      expect_any_instance_of(described_class).to receive(:appointment_destination).once

      subject.build(opts: { questionnaire_response: qr, appointment: appt }, composer: composer.synthesize).draw.to_s
    end
  end

  describe '#provider_text' do
    before do
      allow_any_instance_of(described_class).to receive(:qr_submitted_time).and_return('')
    end

    it 'calls set_text twice' do
      expect_any_instance_of(Prawn::Document).to receive(:text_box).twice

      subject.build(opts: { questionnaire_response: qr, appointment: appt }, composer: composer.synthesize)
             .provider_text
    end
  end

  describe '#appointment_date' do
    it 'calls set_text twice' do
      expect_any_instance_of(described_class).to receive(:set_text).twice

      subject.build(opts: { questionnaire_response: qr, appointment: appt }, composer: composer.synthesize)
             .appointment_date
    end
  end

  describe '#appointment_time' do
    it 'calls set_text twice' do
      expect_any_instance_of(described_class).to receive(:set_text).twice

      subject.build(opts: { questionnaire_response: qr, appointment: appt }, composer: composer.synthesize)
             .appointment_time
    end
  end

  describe '#appointment_destination' do
    it 'calls set_text twice' do
      expect_any_instance_of(described_class).to receive(:set_text).twice

      subject.build(opts: { questionnaire_response: qr, appointment: appt }, composer: composer.synthesize)
             .appointment_destination
    end
  end

  describe '#set_text' do
    context 'when `key`' do
      it 'calls set_text with the right arguments' do
        expect_any_instance_of(Prawn::Document).to receive(:text_box)
          .with('Foo', { at: [30, 541.89], size: 12, style: :normal }).once

        subject.build(opts: { questionnaire_response: qr, appointment: appt }, composer: composer.synthesize)
               .set_text('Foo', 300, 'key')
      end
    end

    context 'when `value`' do
      it 'calls set_text with the correct arguments' do
        expect_any_instance_of(Prawn::Document).to receive(:text_box)
          .with('Foo', { at: [85, 541.89], size: 12, style: :medium }).once

        subject.build(opts: { questionnaire_response: qr, appointment: appt }, composer: composer.synthesize)
               .set_text('Foo', 300, 'value')
      end
    end
  end

  describe '#qr_submitted_time' do
    it 'has a qr_submitted_time' do
      expect(subject.build(opts: { questionnaire_response: qr, appointment: appt }, composer: composer.synthesize)
                    .qr_submitted_time).to eq('February 02, 2001.')
    end
  end

  describe '#formatted_date' do
    it 'has a formatted_date' do
      expect(subject.build(opts: { questionnaire_response: qr, appointment: appt }, composer: composer.synthesize)
                    .formatted_date).to eq('Wednesday, November 18, 2020')
    end
  end

  describe '#formatted_time' do
    it 'has a formatted_time' do
      expect(subject.build(opts: { questionnaire_response: qr, appointment: appt }, composer: composer.synthesize)
                    .formatted_time).to eq('12:00 AM PST')
    end
  end

  describe '#formatted_destination' do
    it 'has a formatted_destination' do
      expect(subject.build(opts: { org:, location: }, composer: composer.synthesize)
                    .formatted_destination).to eq('Foo, Bar')
    end
  end

  describe '#user_data' do
    it 'returns user_data' do
      expect(subject.build(opts: { questionnaire_response: qr, appointment: appt }, composer: composer.synthesize)
                    .user_data).to eq(qr.user_demographics_data)
    end
  end
end
