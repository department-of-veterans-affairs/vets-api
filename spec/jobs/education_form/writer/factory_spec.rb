# frozen_string_literal: true

RSpec.describe EducationForm::Writer::Factory, type: :model, form: :education_benefits do
  subject { described_class }

  it 'raises an error if in production but lacking auth keys' do
    expect(Rails.env).to receive('development?').once { false }

    with_settings(Settings.edu.sftp, host: 'localhost', pass: nil) do
      expect { subject.get_writer }.to raise_error(Exception, /Settings.edu.sftp.pass not set/)
    end
  end

  it 'writes locally for development mode' do
    expect(Rails.env).to receive('development?').once { true }
    expect(subject.get_writer).to be(EducationForm::Writer::Local)
  end

  it 'writes to production when possible' do
    expect(Rails.env).to receive('development?').once { false }

    with_settings(Settings.edu.sftp, host: 'localhost', pass: 'test') do
      expect(subject.get_writer).to be(EducationForm::Writer::Remote)
    end
  end
end
