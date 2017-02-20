

# frozen_string_literal: true
RSpec.describe EducationForm::Writer::Factory, type: :model, form: :education_benefits do
  subject { described_class }

  it 'raises an error if in production but lacking auth keys' do
    expect(Rails.env).to receive('development?').once { false }
    ClimateControl.modify EDU_SFTP_HOST: 'localhost', EDU_SFTP_PASS: nil do
      expect { subject.get_writer }.to raise_error(Exception, /EDU_SFTP_PASS not set/)
    end
  end

  it 'writes locally for development mode' do
    expect(Rails.env).to receive('development?').once { true }
    expect(subject.get_writer).to be(EducationForm::Writer::Local)
  end

  it 'writes to production when possible' do
    expect(Rails.env).to receive('development?').once { false }
    ClimateControl.modify EDU_SFTP_HOST: 'localhost', EDU_SFTP_PASS: 'test' do
      expect(subject.get_writer).to be(EducationForm::Writer::Remote)
    end
  end
end
