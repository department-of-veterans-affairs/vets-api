# frozen_string_literal: true

module SpoolHelpers
  extend ActiveSupport::Concern

  module ClassMethods
    # rubocop:disable Metrics/MethodLength
    def test_spool_file(form_type, test_name, disabled_features = [])
      describe "#{form_type} #{test_name} spool test" do
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

        it 'generates the spool file correctly', run_at: '2017-01-17 03:00:00 -0500' do
          disabled_features.each do |feature|
            allow(Flipper).to receive(:enabled?).with(feature).and_return(false)
          end

          windows_linebreak = EducationForm::CreateDailySpoolFiles::WINDOWS_NOTEPAD_LINEBREAK
          expected_text = File.read("#{file_prefix}spl").rstrip
          expected_text.gsub!("\n", windows_linebreak) unless expected_text.include?(windows_linebreak)

          expect(subject.text).to eq(expected_text)
        end
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
