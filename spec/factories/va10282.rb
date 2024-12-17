# frozen_string_literal: true

FactoryBot.define do
  factory :va10282, class: 'SavedClaim::EducationBenefits::VA10282', parent: :education_benefits do
    form {
      {
        veteranFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        veteranDesc: 'veteran',
        contactInfo: {
          mobilePhone: '1234567890',
          email: 'test@sample.com'
        },
        country: 'United States',
        state: 'FL',
        originRace: {
          isBlackOrAfricanAmerican: true
        },
        gender: 'M',
        highestLevelOfEducation: {
          level: 'MD'
        },
        currentlyEmployed: true,
        currentAnnualSalary: 'moreThanSeventyFive',
        isWorkingInTechIndustry: true,
        techIndustryFocusArea: 'CP'
      }.to_json
    }
  end

  factory :va10282_full_form, class: 'SavedClaim::EducationBenefits::VA10282', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '10282', 'minimal.json').read }
  end
end
