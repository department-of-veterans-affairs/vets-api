# CARMA

CARMA (Caregiver Record Management Application)

## Description

CARMA is a Salesforce application that the VA's Caregivers Program uses to track and process 10-10CG submissions.

This library is used to submit valid, online, 10-10CG submissions (CaregiversAssistanceClaim) to CARMA. It includes an HTTP client and models that map to the CARMA domain.

## Design

### CARMA::Models

Used to hold model objects relating to CARMA's domain. More models can be added as the interface with CARMA grows (i.e. CARMA::Models::Case).

### CARMA::Client

#### CARMA::Client::MuleSoftClient

This is the primary HTTP client used to communicate with CARMA via the MuleSoft API. It handles the submission of 10-10CG data to CARMA and includes monitoring, error handling, and response parsing. The client uses a bearer token for authentication, which is obtained through the `MuleSoftAuthTokenClient`.

#### CARMA::Client::MuleSoftAuthTokenClient

This client is responsible for obtaining a bearer token from the MuleSoft API. It uses client credentials (client ID and client secret) to authenticate and retrieve the token, which is then used by the `MuleSoftClient` for API requests.

## Data Contract

### Submission Request Body

```
{
  data: ref([10-10CG Data Schema](https://github.com/department-of-veterans-affairs/vets-json-schema/blob/master/dist/10-10CG-schema.json)) as json,
  metadata: {
    claimGuid: string;
    claimId: number | null;
    veteran: { icn: string | null; isVeteran?: true | false; },
    primaryCaregiver?: { icn: string | null; isVeteran?: true | false; },
    secondaryCaregiverOne?: { icn: string | null; isVeteran?: true | false; },
    secondaryCaregiverTwo?: { icn: string | null; isVeteran?: true | false; },
  }
}
```

#### Additional Constraints

- If Veteran's status cannot be confirmed as true, icn must be sent as null.
