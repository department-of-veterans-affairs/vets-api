# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require 'roo'
require 'rubyXL'
require 'tempfile'

describe 'user_email_identifier rake task' do # rubocop:disable RSpec/DescribeClass
  describe 'build_csv' do
    let(:task) { Rake::Task['user_email_identifier:build_csv'] }
    let(:idme_email) { create(:user_credential_email) }
    let(:idme_user_verification) { create(:idme_user_verification, user_credential_email: idme_email) }
    let(:logingov_email) { create(:user_credential_email) }
    let(:logingov_user_verification) { create(:logingov_user_verification, user_credential_email: logingov_email) }
    let(:mhv_email) { create(:user_credential_email) }
    let(:mhv_user_verification) { create(:mhv_user_verification, user_credential_email: mhv_email) }
    let(:dslogon_email) { create(:user_credential_email) }
    let(:dslogon_user_verification) { create(:dslogon_user_verification, user_credential_email: dslogon_email) }
    let(:uuid_list) do
      Tempfile.new(['uuid_list', '.xlsx']).tap do |file|
        workbook = RubyXL::Workbook.new
        worksheet = workbook[0]
        worksheet.add_cell(0, 0, 'data_type')
        worksheet.add_cell(0, 1, 'form_type')
        worksheet.add_cell(0, 2, 'va_gov_submission_created_at')
        worksheet.add_cell(0, 3, 'va_gov_user_uuid')
        worksheet.add_cell(1, 0, 'some_data_type')
        worksheet.add_cell(1, 1, 'some_form_type')
        worksheet.add_cell(1, 2, '2019-01-01')
        worksheet.add_cell(1, 3, idme_user_verification.backing_credential_identifier)
        worksheet.add_cell(2, 0, 'some_data_type')
        worksheet.add_cell(2, 1, 'some_form_type')
        worksheet.add_cell(2, 2, '2020-01-01')
        worksheet.add_cell(2, 3, logingov_user_verification.backing_credential_identifier)
        worksheet.add_cell(3, 0, 'some_data_type')
        worksheet.add_cell(3, 1, 'some_form_type')
        worksheet.add_cell(3, 2, '2021-01-01')
        worksheet.add_cell(3, 3, mhv_user_verification.backing_credential_identifier)
        worksheet.add_cell(4, 0, 'some_data_type')
        worksheet.add_cell(4, 1, 'some_form_type')
        worksheet.add_cell(4, 2, '2022-01-01')
        worksheet.add_cell(4, 3, dslogon_user_verification.backing_credential_identifier)
        worksheet.add_cell(5, 0, 'some_data_type')
        worksheet.add_cell(5, 1, 'some_form_type')
        worksheet.add_cell(5, 2, '2023-01-01')
        worksheet.add_cell(5, 3, 'some-unknown-uuid')
        workbook.write(file.path)
      end
    end
    let(:output_path) { './tmp/user_email_identifiers.csv' }

    before do
      Rake.application.rake_require '../rakelib/user_email_identifier'
      Rake::Task.define_task(:environment)
    end

    after do
      uuid_list.unlink
    end

    it 'adds the queried credential emails to the produced CSV' do
      task.invoke(uuid_list.path)

      csv_content = CSV.read(output_path)
      expect(csv_content.size).to eq(6)
      expect(csv_content[1]).to eq(['some_data_type', 'some_form_type', '2019-01-01',
                                    idme_user_verification.backing_credential_identifier,
                                    idme_email.credential_email])
      expect(csv_content[2]).to eq(['some_data_type', 'some_form_type', '2020-01-01',
                                    logingov_user_verification.backing_credential_identifier,
                                    logingov_email.credential_email])
      expect(csv_content[3]).to eq(['some_data_type', 'some_form_type', '2021-01-01',
                                    mhv_user_verification.backing_credential_identifier,
                                    mhv_email.credential_email])
      expect(csv_content[4]).to eq(['some_data_type', 'some_form_type', '2022-01-01',
                                    dslogon_user_verification.backing_credential_identifier,
                                    dslogon_email.credential_email])
    end

    it 'does not add the queried credential email to the produced CSV when a user verification is not found' do
      task.invoke(uuid_list.path)

      csv_content = CSV.read(output_path)
      expect(csv_content[5]).to eq(%w[some_data_type some_form_type 2023-01-01 some-unknown-uuid])
    end

    it 'logs an alert to the console when a user verification is not found' do
      expect { task.invoke(uuid_list.path) }.to output(
        "[UserEmailIdentifier] Building CSV from #{uuid_list.path}, processing 5 rows...\n" \
        "[UserEmailIdentifier] Error: UserVerification not found for uuid: some-unknown-uuid\n" \
        "[UserEmailIdentifier] CSV creation successful, file location: tmp/user_email_identifiers.csv\n"
      ).to_stdout
    end
  end
end
