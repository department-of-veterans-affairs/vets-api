# frozen_string_literal: true

require 'faker'
require 'json'
require 'date'

I = Faker::Internet
A = Faker::Address
N = Faker::Name
P = Faker::PhoneNumber
NUM = Faker::Number
L = Faker::Lorem

# rubocop:disable all
def submit_hash
  homeless = random_bool

  {
    "form526": {
      "veteran": {
        "emailAddress": I.email,
        "alternateEmailAddress": (I.email if random_bool),
        "mailingAddress": address,
        "forwardingAddress": (address.merge("effectiveDate": date) if random_bool),
        "primaryPhone": P.phone_number,
        "homelessness": {
          "isHomeless": homeless,
          "pointOfContact": (if homeless
                             {
                               "pointOfContactName": N.name,
                               "primaryPhone": P.phone_number
                             }
                            end)
        },
        "serviceNumber": (NUM.number(9) if random_bool)
      },
      "attachments": (if random_bool
                      [{
                        "documentName": L.word,
                        "dateUploaded": date,
                        "attachmentType": L.word,
                        "inflightDocumentId": NUM.number(10)
                      }]
                      end),
      "mililtaryPayments": (if random_bool
                            {
                              "payments": [{
                                "payType": pay_type,
                                "amount": NUM.number(5)
                              }],
                              "receiveCompensationInLieuOfRetired": random_bool
                            }
                           end),
      "serviceInformation": {
        "servicePeriods": [{
          "serviceBranch": service_branch,
          "dateRange": date_range
        }],
        "reservesNationalGuardService": (if random_bool
                                         {
                                           "title10Activation": (if random_bool
                                                                 {
                                                                   "title10ActivationDate": date,
                                                                   "anticipatedSeparationDate": date
                                                                 }
                                                                end),
                                           "obligationTermsOfServiceDateRange": date_range,
                                           "unitName": L.word,
                                           "unitPhone": P.phone_number,
                                           "inactiveDutyTrainingPay": (if random_bool
                                                                       {
                                                                         "waiveVABenefitsToRetainTrainingPay": random_bool
                                                                       }
                                                                       end)
                                         }
                                        end),
        "servedInCombatZone": random_bool,
        "separationLocationName": (L.word if random_bool),
        "separationLocationCode": (L.word if random_bool),
        "alternateNames": ([N.name] if random_bool),
        "confinements": (if random_bool
                         [{
                           "confinementDateRange": date_range,
                           "verifiedIndicator": random_bool
                         }]
                        end)
      },
      "disabilities": {
        "name": L.word,
        "disabilityActionType": disability_action_type,
        "specialIssues": (if random_bool
                          [{
                            "code": special_issue_code,
                            "name": L.word
                          }]
                         end),
        "ratedDisabilityId": (L.word if random_bool),
        "ratingDecisionId": (L.word if random_bool),
        "diagnosticCode": (NUM.number(5) if random_bool),
        "classificationCode": (L.word if random_bool)
      },
      "treatments": (if random_bool
                      [{
                        "treatmentCenterName": L.word,
                        "treatmentDateRange": (date_range if random_bool),
                        "treatmentCenterAddress": (address.slice("country", "city", "state") if random_bool),
                        "treatmentCenterType": treatment_center_type
                      }]
                    end),
      "specialCircumstances": (if random_bool
                               [{
                                 "name": L.word,
                                 "code": L.word,
                                 "needed": random_bool
                               }]
                              end),
      "standardClaim": random_bool,
      "claimantCertification": random_bool
    }
  }
end
# rubocop:enable all

def random_bool
  [true, false].sample
end

def address
  {
    "addressLine1": A.street_address,
    "addressLine2": (A.secondary_address if random_bool),
    "city": A.city,
    "state": (A.state_abbr if random_bool),
    "zipCode": (A.zip if random_bool),
    "country": A.country
  }
end

# rubocop:disable all
def date(years_ago = 2)
  DateTime.parse(Faker::Date.between(Date.today - (years_ago * 365), Date.today).to_s)
end
# rubocop:enable all

def date_range
  {
    "from": date(3),
    "to": date
  }
end

def pay_type
  %w[LONGEVITY TEMPORARY_DISABILITY_RETIRED_LIST PERMANENT_DISABILITY_RETIRED_LIST SEPARATION SEVERANCE].sample
end

def service_branch
  [
    'Air Force',
    'Air Force Reserve',
    'Air National Guard',
    'Army',
    'Army National Guard',
    'Army Reserve',
    'Coast Guard',
    'Coast Guard Reserve',
    'Marine Corps',
    'Marine Corps Reserve',
    'NOAA',
    'Navy',
    'Navy Reserve',
    'Public Health Service'
  ].sample
end

def disability_action_type
  %w[NONE NEW SECONDARY INCREASE REOPEN].sample
end

def special_issue_code
  [
    'ALS',
    'AOIV',
    'AOOV',
    'ASB',
    'EHCL',
    'GW',
    'HEPC',
    'MG',
    'POW',
    'RDN',
    'SHAD',
    'TRM',
    '38USC1151',
    'PTSD/1',
    'PTSD/2',
    'PTSD/4)'
  ].sample
end

def treatment_center_type
  %w[VA_MEDICAL_CENTER DOD_MTF].sample
end

puts submit_hash.to_json
