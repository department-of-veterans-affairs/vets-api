# frozen_string_literal: true

FactoryBot.define do
  factory :va1995, class: 'SavedClaim::EducationBenefits::VA1995', parent: :education_benefits do
    form {
      {
        veteranFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        veteranSocialSecurityNumber: '111223333',
        benefit: 'transferOfEntitlement',
        privacyAgreementAccepted: true
      }.to_json
    }

    factory :va1995_full_form do
      form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1995', 'kitchen_sink.json').read }
    end

    factory :va1995_with_stem do
      form {
        Rails.root.join(
          'spec',
          'fixtures',
          'education_benefits_claims',
          '1995'
        ).read
      }
    end

    factory :va1995_ch33_post911 do
      form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1995', 'ch33_post911.json').read }
    end

    factory :va1995_ch33_fry do
      form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1995', 'ch33_fry.json').read }
    end

    # Montgomery GI Bill (MGIB-AD, Chapter 30)
    factory :va1995_ch30 do
      form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1995', 'ch30.json').read }
    end

    # Montgomery GI Bill Selected Reserve (MGIB-SR, Chapter 1606)
    factory :va1995_ch1606 do
      form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1995', 'ch1606.json').read }
    end
  end
end
