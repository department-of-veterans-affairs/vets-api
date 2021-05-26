# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::QuestionnaireResponseReport do
  subject { described_class }

  describe 'constants' do
    it 'has a DATE_FORMAT' do
      expect(described_class::DATE_FORMAT).to eq('%A, %B %d, %Y')
    end

    it 'has a TIME_FORMAT' do
      expect(described_class::TIME_FORMAT).to eq('%-I:%M %p')
    end

    it 'has a VA_LOGO' do
      expect(described_class::VA_LOGO).to eq('modules/health_quest/app/assets/images/va_logo.png')
    end

    it 'has a VA_URL' do
      expect(described_class::VA_URL).to eq('https://va.gov/')
    end
  end

  describe '.manufacture' do
    it 'returns an instance of subject' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)

      expect(subject.manufacture({})).to be_a(subject)
    end
  end

  describe 'attributes' do
    before do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
    end

    it 'responds to questionnaire_response' do
      expect(subject.manufacture({}).respond_to?(:questionnaire_response)).to eq(true)
    end

    it 'responds to appointment' do
      expect(subject.manufacture({}).respond_to?(:appointment)).to eq(true)
    end

    it 'responds to location' do
      expect(subject.manufacture({}).respond_to?(:location)).to eq(true)
    end

    it 'responds to org' do
      expect(subject.manufacture({}).respond_to?(:org)).to eq(true)
    end
  end

  describe '#build_content' do
    before do
      allow_any_instance_of(described_class).to receive(:set_font).and_return('')
      allow_any_instance_of(described_class).to receive(:set_header).and_return('')
      allow_any_instance_of(described_class).to receive(:set_footer).and_return('')
      allow_any_instance_of(described_class).to receive(:set_body).and_return('')
    end

    it 'builds the content' do
      expect(subject.manufacture({}).build_content).to be_a(String)
    end
  end

  describe '#header_columns' do
    before do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      Timecop.freeze(Time.now.in_time_zone.to_date.to_s)
    end

    after do
      Timecop.return
    end

    it 'first row is today' do
      date = DateTime.now.to_date.strftime('%m/%d/%Y')

      expect(subject.manufacture({}).header_columns.first.first).to eq(date)
    end

    it 'last row is VA_URL' do
      expect(subject.manufacture({}).header_columns.first.last).to eq('https://va.gov/')
    end
  end

  describe '#set_font' do
    it 'sets the font to HealthQuestPDF' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)

      expect(subject.manufacture({}).set_font.family).to eq('HealthQuestPDF')
    end
  end

  describe '#set_logo' do
    it 'sets the logo' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)

      expect(subject.manufacture({}).set_logo.to_s).to include('Prawn::Images::PNG')
    end
  end

  describe '#set_header' do
    it 'sets the header bounding box' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:qr_data).and_return({})
      allow_any_instance_of(subject).to receive(:org_name).and_return('')

      expect(subject.manufacture({}).set_header.to_s).to include('Prawn::Document::BoundingBox')
    end
  end

  describe '#set_footer' do
    it 'sets the footer bounding box' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:user_data).and_return({ 'date_of_birth' => '1998-01-02' })

      expect(subject.manufacture({}).set_footer.to_s).to include('Prawn::Document::BoundingBox')
    end
  end

  describe '#set_body' do
    it 'sets the bounding box for the body' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:set_basic_appointment_info).and_return(nil)
      allow_any_instance_of(subject).to receive(:set_basic_demographics).and_return(nil)
      allow_any_instance_of(subject).to receive(:set_qr_header).and_return(nil)
      allow_any_instance_of(subject).to receive(:set_questionnaire_items).and_return(nil)

      expect(subject.manufacture({}).set_body.to_s).to include('Prawn::Document::BoundingBox')
    end
  end

  describe '#set_basic_appointment_info' do
    it 'sets the set_basic_appointment_info table' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:set_provider_info_text).and_return(nil)
      allow_any_instance_of(subject).to receive(:appointment_date).and_return('')
      allow_any_instance_of(subject).to receive(:appointment_time).and_return('')
      allow_any_instance_of(subject).to receive(:appointment_destination).and_return('')

      expect(subject.manufacture({}).set_basic_appointment_info.to_s).to include('Prawn::Table')
    end
  end

  describe '#set_basic_demographics' do
    it 'sets the set_basic_demographics table' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:set_about).and_return([['']])
      allow_any_instance_of(subject).to receive(:set_address).and_return([['']])
      allow_any_instance_of(subject).to receive(:set_phone).and_return([['']])

      expect(subject.manufacture({}).set_basic_demographics.to_s).to include('Prawn::Table')
    end
  end

  describe '#set_about' do
    it 'sets the set_about array' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:user_data).and_return({ 'date_of_birth' => '1998-01-02' })
      allow_any_instance_of(subject).to receive(:full_name).and_return(nil)

      array = [['Name:', nil], ['Date of birth:', '01/02/1998'], ['Gender:', nil]]

      expect(subject.manufacture({}).set_about).to eq(array)
    end
  end

  describe '#set_address' do
    it 'sets the set_address array' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:user_data).and_return({})

      array = [['Country:', nil], ['Mailing address:', nil], ['Home address:', nil]]

      expect(subject.manufacture({}).set_address).to eq(array)
    end
  end

  describe '#format_address' do
    it 'returns nil if address is blank' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)

      expect(subject.manufacture({}).format_address({})).to eq(nil)
    end

    it 'returns a formatted address' do
      hsh = {
        'address_line1' => '521 W Cedar St',
        'address_line2' => 'Line Two',
        'address_line3' => 'Line Three',
        'city' => 'Atlanta',
        'state_code' => 'GA',
        'zip_code' => '82301'
      }
      address = '521 W Cedar St Line Two Line Three, Atlanta, GA 82301'

      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)

      expect(subject.manufacture({}).format_address(hsh)).to eq(address)
    end
  end

  describe '#format_phone' do
    it 'returns nil if phone is blank' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)

      expect(subject.manufacture({}).format_phone({})).to eq(nil)
    end

    it 'returns a formatted phone' do
      hsh = {
        'area_code' => '313',
        'phone_number' => '6220000'
      }
      phone = '313-622-0000'

      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)

      expect(subject.manufacture({}).format_phone(hsh)).to eq(phone)
    end
  end

  describe '#set_phone' do
    it 'sets the set_phone array' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:user_data).and_return({})

      array = [['Home phone:', nil], ['Mobile phone:', nil], ['Work phone:', nil]]

      expect(subject.manufacture({}).set_phone).to eq(array)
    end
  end

  describe '#set_questionnaire_items' do
    let(:qr) do
      double(
        'QuestionnaireResponse',
        questionnaire_response_data: {
          'item' => [{ 'answer' => [{ 'valueString' => 'bar' }], 'text' => 'foo' }]
        }
      )
    end

    it 'returns the items' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:questionnaire_response).and_return(qr)

      expect(subject.manufacture({}).set_questionnaire_items).to eq(qr.questionnaire_response_data['item'])
    end
  end

  describe '#set_provider_info_text' do
    it 'sets the set_provider_info_text table' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:qr_submitted_time).and_return('')

      expect(subject.manufacture({}).set_provider_info_text.to_s).to include('Prawn::Table')
    end
  end

  describe '#today' do
    it 'returns today\'s date' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      date = DateTime.now.to_date.strftime('%m/%d/%Y')

      expect(subject.manufacture({}).today).to eq(date)
    end
  end

  describe '#appointment_destination' do
    it 'has an appointment_destination' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:loc_name).and_return('Foo')
      allow_any_instance_of(subject).to receive(:org_name).and_return('Bar')

      expect(subject.manufacture({}).appointment_destination).to eq('Foo, Bar')
    end
  end

  describe '#full_name' do
    it 'has a full_name' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:user_data)
        .and_return({ 'first_name' => 'Bob', 'last_name' => 'Smith' })

      expect(subject.manufacture({}).full_name).to eq('Bob Smith')
    end
  end

  describe '#org_name' do
    let(:org) do
      double('Org', resource: double('Resource', name: 'Bar'))
    end

    it 'has an org_name' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:org).and_return(org)

      expect(subject.manufacture({}).org_name).to eq('Bar')
    end
  end

  describe '#loc_name' do
    let(:location) do
      double('Location', resource: double('Resource', name: 'Foo'))
    end

    it 'has a loc_name' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:location).and_return(location)

      expect(subject.manufacture({}).loc_name).to eq('Foo')
    end
  end

  describe '#info' do
    it 'returns the PDF info' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)

      Timecop.freeze(Time.zone.now)

      hsh = {
        Lang: 'en-us',
        Title: 'Primary Care Questionnaire',
        Author: 'Department of Veterans Affairs',
        Subject: 'Primary Care Questionnaire',
        Keywords: 'health questionnaires pre-visit',
        Creator: 'va.gov',
        Producer: 'va.gov',
        CreationDate: Time.zone.now
      }

      expect(subject.manufacture({}).info).to eq(hsh)
      Timecop.return
    end
  end

  describe '#qr_submitted_time' do
    let(:qr) do
      double(
        'QuestionnaireResponse',
        created_at: DateTime.parse('2001-02-03T04:05:06')
      )
    end

    it 'returns the submitted time' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:questionnaire_response).and_return(qr)

      expect(subject.manufacture({}).qr_submitted_time).to eq('February 02, 2001.')
    end
  end

  describe '#appointment_date' do
    let(:appt) do
      double(
        'Appointment',
        resource: double('Resource', start: '2020-11-18T08:00:00Z')
      )
    end

    it 'returns the appointment date' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:appointment).and_return(appt)

      expect(subject.manufacture({}).appointment_date).to eq('Wednesday, November 18, 2020')
    end
  end

  describe '#appointment_time' do
    let(:appt) do
      double(
        'Appointment',
        resource: double('Resource', start: '2020-11-18T08:00:00Z')
      )
    end

    it 'returns the appointment time' do
      allow_any_instance_of(subject).to receive(:build_content).and_return(nil)
      allow_any_instance_of(subject).to receive(:appointment).and_return(appt)

      expect(subject.manufacture({}).appointment_time).to eq('12:00 AM PST')
    end
  end
end
