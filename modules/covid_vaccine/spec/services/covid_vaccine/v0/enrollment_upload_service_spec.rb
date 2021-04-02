# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::EnrollmentUploadService do
  subject do
    described_class.new(io, file_name)
  end

  let(:io) { StringIO.new(File.read('modules/covid_vaccine/spec/fixtures/csv_string.txt')) }
  let(:file_name) { 'DHS_load_20210402080000_SLA_12_records.txt' }

  it 'responds to #io' do
    expect(subject.io).to be_a(StringIO)
    expect(subject.io.size).to eq(1497)
  end

  it 'responds to #file_name' do
    expect(subject.file_name).to eq(file_name)
  end

  context 'sftp interactions' do
    let(:host) { 'fake_host' }
    let(:username) { 'fake_username' }
    let(:password) { 'fake_password' }
    let(:sftp_connection_double) { double(:sftp_connection_double, upload!: true, download!: true) }
    let(:sftp_double) { double(:sftp, sftp: sftp_connection_double) }
    let(:handler) { CovidVaccine::V0::EnrollmentHandler }

    it 'responds to send_enrollment_file' do
      expect(Net::SFTP).to receive(:start).with(host, username, password: password).and_yield(sftp_connection_double)
      expect(sftp_connection_double)
        .to receive(:upload!).with(subject.io, file_name, name: file_name, progress: instance_of(handler))
      subject.upload
    end
  end
end
