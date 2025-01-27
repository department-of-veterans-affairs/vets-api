# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::PdfGenerator::QuestionnaireResponseInfo do
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
      },
      questionnaire_response_data: {
        'item' => [{ 'answer' => [{ 'valueString' => 'bar' }], 'text' => 'foo' }]
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
    it 'is an instance of QuestionnaireResponseInfo' do
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
      allow_any_instance_of(described_class).to receive(:visit_header).and_return('')
      allow_any_instance_of(described_class).to receive(:questionnaire_items).and_return('')
    end

    it 'uses calls the appropriate methods' do
      expect_any_instance_of(described_class).to receive(:visit_header).once
      expect_any_instance_of(described_class).to receive(:questionnaire_items).once

      subject.build(opts: { questionnaire_response: qr, appointment: appt }, composer: composer.synthesize).draw.to_s
    end
  end

  describe '#visit_header' do
    it 'calls text_box once' do
      expect_any_instance_of(Prawn::Document).to receive(:text_box).once

      subject.build(opts: {}, composer: composer.synthesize).visit_header.to_s
    end
  end

  describe '#questionnaire_items' do
    it 'calls prawn methods' do
      items =
        subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).questionnaire_items.to_s

      expect(items).to include('foo')
      expect(items).to include('bar')
    end
  end
end
