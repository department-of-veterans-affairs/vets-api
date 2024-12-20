# frozen_string_literal: true

module ExcelHelpers
  extend ActiveSupport::Concern

  module ClassMethods
    # rubocop:disable Metrics/MethodLength
    def test_excel_file(form_type, test_name, disabled_features = [])
      describe "#{form_type} #{test_name} excel test" do
        subject do
          described_class.new(education_benefits_claim)
        end

        let(:file_prefix) { "spec/fixtures/education_benefits_claims/#{form_type}/#{test_name}." }
        let(:form_class) { "SavedClaim::EducationBenefits::VA#{form_type}".constantize }
        let(:education_benefits_claim) do
          form_class.create!(
            form: File.read("#{file_prefix}json")
          ).education_benefits_claim
        end

        before do
          allow(education_benefits_claim).to receive(:id).and_return(1)
          education_benefits_claim.instance_variable_set(:@application, nil)
        end

        it 'generates the excel data correctly', run_at: '2017-01-17 03:00:00 -0500' do
          disabled_features.each do |feature|
            allow(Flipper).to receive(:enabled?).with(feature).and_return(false)
          end

          expected_data = CSV.read("#{file_prefix}csv", headers: true)

          # Format the application data using the form object
          form = subject
          row_data = EducationForm::CreateDailyExcelFiles::EXCEL_FIELDS.map do |field|
            form.public_send(field)
          end

          # Create CSV data for comparison
          generated_csv = CSV.generate do |csv|
            csv << EducationForm::CreateDailyExcelFiles::HEADERS
            csv << row_data
          end
          generated_data = CSV.parse(generated_csv, headers: true)

          # Compare headers
          expect(generated_data.headers).to eq(EducationForm::CreateDailyExcelFiles::HEADERS)

          # Compare data row by row
          expected_data.each_with_index do |expected_row, index|
            generated_row = generated_data[index]

            EducationForm::CreateDailyExcelFiles::EXCEL_FIELDS.each_with_index do |field, field_index|
              expect(generated_row[field_index]).to eq(expected_row[field_index]),
                                                    "Mismatch in #{field} for row #{index + 1}. " \
                                                    "Expected: #{expected_row[field_index]}, " \
                                                    "Got: #{generated_row[field_index]}"
            end
          end
        end
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
