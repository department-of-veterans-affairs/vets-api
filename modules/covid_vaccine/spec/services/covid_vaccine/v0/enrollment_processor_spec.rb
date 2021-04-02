# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::EnrollmentProcessor do
  subject do
    described_class.new
  end

  let(:records) do
    subs = YAML.load_file('modules/covid_vaccine/spec/fixtures/expanded_registration_submissions.yml')
    subs.values.map do |s|
      FactoryBot.create(:covid_vax_expanded_registration, state: 'received', raw_form_data: s['raw_form_data'])
    end
  end

  around do |example|
    Timecop.freeze(Time.zone.parse('2021-04-02T00:00:00Z'))
    example.run
    Timecop.return
  end

  context 'EnrollmentProcessor#generated_file_name' do
    it 'builds a file_name based on default prefix' do
      expect(subject.generated_file_name(1)).to eq('DHS_load_20210402000000_SLA_1_records.txt')
    end

    it 'builds a file_name based on custom prefix' do
      expect(described_class.new(prefix: 'TEST').generated_file_name(1)).to eq('TEST_20210402000000_SLA_1_records.txt')
    end
  end

  context '#batch_records!' do
    it 'changes records having state to have batch id' do
      records
      batched_records = subject.batch_records!
      expect(batched_records).to eq(records.size)
      expect(batched_records.map(&:batch_id)).to all(eq('20210402000000'))
    end 
  end  

end
