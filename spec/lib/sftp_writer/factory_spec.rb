# frozen_string_literal: true

RSpec.describe SFTPWriter::Factory, type: :model, form: :education_benefits do
  subject { described_class }

  it 'raises an error if in production but lacking auth keys' do
    expect(Rails.env).to receive('development?').once.and_return(false)

    with_settings(Settings.edu.sftp, host: 'localhost', pass: nil) do
      expect { subject.get_writer(Settings.edu.sftp) }.to raise_error(Exception, /SFTP password not set/)
    end
  end

  it 'writes locally for development mode' do
    expect(Rails.env).to receive('development?').once.and_return(true)
    expect(subject.get_writer(Settings.edu.sftp)).to be(SFTPWriter::Local)
  end

  it 'writes to production when possible' do
    expect(Rails.env).to receive('development?').once.and_return(false)

    with_settings(Settings.edu.sftp, host: 'localhost', pass: 'test') do
      expect(subject.get_writer(Settings.edu.sftp)).to be(SFTPWriter::Remote)
    end
  end
end
