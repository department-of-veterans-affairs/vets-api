# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::EnrollmentService do
  subject do
    described_class.new(records)
  end

  let(:records) do
    fixture_file = YAML.load_file('modules/covid_vaccine/spec/fixtures/expanded_registration_submissions.yml')
    fixture_file.values.map do |fixture|
      FactoryBot.build(:covid_vax_expanded_registration,
                       raw_form_data: fixture['raw_form_data'],
                       eligibility_info: fixture['eligibility_info'])
    end
  end

  it 'responds to #records' do
    expect(subject.records).to be_an(Array)
    expect(subject.records.first).to be_a(CovidVaccine::V0::ExpandedRegistrationSubmission)
    expect(subject.records.size).to eq(12)
  end

  it 'responds to #io' do
    expect(subject.io).to be_a(StringIO)
    expect(subject.io.size).to eq(1497)
  end

  context 'sftp interactions' do
    let(:host) { 'fake_host' }
    let(:username) { 'fake_username' }
    let(:password) { 'fake_password' }
    let(:sftp_connection_double) { double(:sftp_connection_double, upload!: true, download!: true) }
    let(:sftp_double) { double(:sftp, sftp: sftp_connection_double) }
    let(:timestamp) { Time.zone.parse('2021-03-31T08:00:00Z') }
    let(:name) { "DHS_load_#{timestamp.strftime('%Y%m%d%H%M%S')}_SLA_#{records.size}_records.txt" }
    let(:handler) { CovidVaccine::V0::EnrollmentHandler }

    it 'responds to send_enrollment_file' do
      Timecop.freeze(timestamp)
      expect(Net::SFTP).to receive(:start).with(host, username, password: password).and_yield(sftp_connection_double)
      expect(sftp_connection_double)
        .to receive(:upload!).with(subject.io, "/#{name}", name: name, progress: instance_of(handler))
      subject.send_enrollment_file
      Timecop.return
    end

    it 'responds to send_enrollment_file with a suffix on filename' do
      Timecop.freeze(timestamp)
      n = 'TESTING_' + name
      expect(Net::SFTP).to receive(:start).with(host, username, password: password).and_yield(sftp_connection_double)
      expect(sftp_connection_double)
        .to receive(:upload!).with(subject.io, "/#{n}", name: n, progress: instance_of(handler))
      subject.send_enrollment_file(file_name_prefix: 'TESTING_')
      Timecop.return
    end
  end
end
