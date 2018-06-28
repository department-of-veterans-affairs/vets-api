require 'faker'
require 'json'
require 'date'

I = Faker::Internet
A = Faker::Address
N = Faker::Name
P = Faker::PhoneNumber
NUM = Faker::Number
L = Faker::Lorem


def submit_hash
  homeless = random_bool

  {
    "form526": {
      "veteran": {
        "emailAddress": I.email,
        "alternateEmailAddress": (I.email if random_bool),
        "mailingAddress": address,
        "forwardingAddress": (address.merge({ "effectiveDate": date }) if random_bool),
        "primaryPhone": P.phone_number,
        "homelessness": {
          "isHomeless": homeless,
          "pointOfContact": ({
            "pointOfContactName": N.name,
            "primaryPhone": P.phone_number
          } if homeless)
        },
        "serviceNumber": (NUM.number(9) if random_bool)
      },
      "attachments": ([{
        "documentName": L.word,
        "dateUploaded": date,
        "attachmentType": L.word,
        "inflightDocumentId": NUM.number(10)
      }] if random_bool),
      "mililtaryPayments": ({
        "payments": [{
          "payType": pay_type,
          "amount": NUM.number(5)
        }],
        "receiveCompensationInLieuOfRetired": random_bool
      } if random_bool),
      "serviceInformation": {
        "servicePeriods": [{
          "serviceBranch": service_branch,
          "dateRange": date_range
        }],
        "reservesNationalGuardService": ({
          "title10Activation": ({
            "title10ActivationDate": date,
            "anticipatedSeparationDate": date
          } if random_bool),
          "obligationTermsOfServiceDateRange": date_range,
          "unitName": L.word,
          "unitPhone": P.phone_number,
          "inactiveDutyTrainingPay": ({
            "waiveVABenefitsToRetainTrainingPay": random_bool
          } if random_bool)
        } if random_bool),
        "servedInCombatZone": random_bool,
        "separationLocationName": (L.word if random_bool),
        "separationLocationCode": (L.word if random_bool),
        "alternateNames": ([N.name] if random_bool),
        "confinements": ([{
          "confinementDateRange": date_range,
          "verifiedIndicator": random_bool
        }] if random_bool)
      },
      "disabilities": {
        "name": L.word,
        "disabilityActionType": disability_action_type,
        "specialIssues": ([{
          "code": special_issue_code,
          "name": L.word
        }] if random_bool),
        "ratedDisabilityId": (L.word if random_bool),
        "ratingDecisionId": (L.word if random_bool),
        "diagnosticCode": (NUM.number(5) if random_bool),
        "classificationCode": (L.word if random_bool)
      },
      "treatments": ([{
        "treatmentCenterName": L.word,
        "treatmentDateRange": (date_range if random_bool),
        "treatmentCenterAddress": (address if random_bool),
        "treatmentCenterType": treatment_center_type
      }] if random_bool),
      "specialCircumstances": ([{
        "name": L.word,
        "code": L.word,
        "needed": random_bool
      }] if random_bool),
      "applicationExpirationDate": "",
      "standardClaim": random_bool,
      "claimantCertification": random_bool
    }
  }
end

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

def date(years_ago = 2)
  DateTime.parse(Faker::Date.between(Date.today - (years_ago*365), Date.today).to_s)
end

def date_range
  {
    "from": date(3),
    "to": date
  }
end

def pay_type
  [ 'LONGEVITY', 'TEMPORARY_DISABILITY_RETIRED_LIST', 'PERMANENT_DISABILITY_RETIRED_LIST', 'SEPARATION', 'SEVERANCE' ].sample
end

def service_branch
  [ 'Air Force', 'Air Force Reserve', 'Air National Guard', 'Army', 'Army National Guard', 'Army Reserve', 'Coast Guard', 'Coast Guard Reserve', 'Marine Corps', 'Marine Corps Reserve', 'NOAA', 'Navy', 'Navy Reserve', 'Public Health Service' ].sample
end

def disability_action_type
  ['NONE', 'NEW', 'SECONDARY', 'INCREASE', 'REOPEN'].sample
end

def special_issue_code
  [ 'ALS', 'AOIV', 'AOOV', 'ASB', 'EHCL', 'GW', 'HEPC', 'MG', 'POW', 'RDN', 'SHAD', 'TRM', '38USC1151', 'PTSD/1', 'PTSD/2', 'PTSD/4)' ].sample
end

def treatment_center_type
  ['VA_MEDICAL_CENTER', 'DOD_MTF'].sample
end

puts submit_hash.to_json
