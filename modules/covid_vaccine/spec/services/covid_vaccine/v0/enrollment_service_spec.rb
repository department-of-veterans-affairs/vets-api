# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::EnrollmentService do
  subject do 
    described_class.new(records)
  end

  let(:records) do
    fixture_file = YAML.load_file('modules/covid_vaccine/spec/fixtures/expanded_registration_submissions.yml')
    records = fixture_file.values.map do |fixture|
      FactoryBot.build(:covid_vax_expanded_registration,
                        raw_form_data: fixture['raw_form_data'],
                        eligibility_info: fixture['eligibility_info'])
    end
  end

  it 'responds to #records' do
    expect(subject.records).to be_an(Array)
    expect(subject.records.first).to be_a(CovidVaccine::V0::ExpandedRegistrationSubmission)
    expect(subject.records.size).to eq(9)
  end

  it 'responds to #io' do
    expect(subject.io).to be_a(StringIO)
    expect(subject.io.size).to eq(1426)
  end

  context 'sftp interactions' do
    let(:host) { }
    let(:username) { }
    let(:password) { }
    let(:timestamp) { Time.now.utc.parse('2021-03-31T08:00:00Z') }
    let(:name) { "#{timestamp.strftime('%Y%m%d%H%M%S')}_saves_lives_act_#{records.size}_records.txt" }

    it 'responds to send_enrollment_file' do
      Timecop.freeze()
      expect(Net::SFTP).to receive(:start).with(host, username, password: password).and_yield(sftp_double)
      expect(sftp_double).to receive(:upload!).with(subject.io, "/#{name}", name: name, progress: EnrollmentHandler.new)
      subject.send_enrollment_file
      Timecop.return
    end

    it 'responds to send_enrollment_file with a suffix on filename' do
      Timecop.freeze()
      n = name + '_TEST'
      expect(Net::SFTP).to receive(:start).with(host, username, password: password).and_yield(sftp_double)
      expect(sftp_double).to receive(:upload!).with(subject.io, "/#{n}", name: n, progress: EnrollmentHandler.new)
      subject.send_enrollment_file('_TEST')
      Timecop.return
    end
  end
end
