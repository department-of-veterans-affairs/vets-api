# frozen_string_literal: true

FactoryBot.define do
  factory :increase_compensation_claim, class: 'IncreaseCompensation::SavedClaim' do
    form_id { '21-8940' }
    form do
      {
        veteranFullName: {
          first: 'Johnny',
          middleinitial: 'D',
          last: 'Rico'
        },
        vaFileNumber: 'C12345678',
        dateOfBirth: '1975-03-15',
        veteranSocialSecurityNumber: '333224444',
        veteranPhone: '3075551234',
        veteranAddress: {
          country: 'US',
          state: 'WY',
          postalCode: '82001',
          street: '123 Starship Lane',
          street2: '4B',
          city: 'Cheyenne'
        },
        doctorsTreatmentDates: {
          from: '2024-01-10',
          to: '2025-02-20'
        },
        hospitalCareDateRanges: {
          from: '2024-06-01',
          to: '2024-06-15'
        },
        previousEmployers: [],
        appliedEmployers: [],
        education: {},
        educationTrainingPreUnemployability: {
          datesOfTraining: {
            from: '2001-01-15',
            to: '2001-03-30'
          },
          name: 'scholl'
        },
        educationTrainingPostUnemployability: {
          datesOfTraining: {
            from: '2019-04-01',
            to: '2019-04-30'
          },
          name: 'technical'
        },
        signature: 'Johnny Rico',
        signatureDate: '2025-10-09',
        witnessSignature1: {
          signature: 'Carmen Ibanez',
          address: '303 Fleet Ave, Cheyenne, WY 82001'
        },
        witnessSignature2: {
          signature: 'Carl Jenkins',
          address: '456 Medical St, Cheyenne, WY 82001'
        }
      }.to_json
    end
  end
end
