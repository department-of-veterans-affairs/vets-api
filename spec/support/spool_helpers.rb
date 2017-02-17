module SpoolHelpers
  extend ActiveSupport::Concern

  module ClassMethods
    def test_spool_file(form_type, test_name)
      describe "#{form_type} #{test_name} spool test" do
        let(:file_prefix) { "spec/fixtures/education_benefits_claims/#{form_type}/#{test_name}." }

        before do
          education_benefits_claim.form = File.read("#{file_prefix}json")
          education_benefits_claim.save!
          allow(education_benefits_claim).to receive(:id).and_return(1)
        end

        it 'should generate the spool file correctly', run_at: '2017-01-17 03:00:00 -0500' do
          expected_text = File.read("#{file_prefix}spl").rstrip
          expected_text.gsub!("\n", EducationForm::WINDOWS_NOTEPAD_LINEBREAK)

          expect(subject.text).to eq(expected_text)
        end
      end
    end
  end
end
