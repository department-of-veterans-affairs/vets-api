# CARMA
CARMA (Caregiver Record Management Application)

## Description
CARMA (Caregiver Record Management Application) is a Salesforce application that the VA's Caregivers Program uses to intake, track, and process 10-10CG submissions.

This CARMA service/module is used to submit valid, online, 10-10CG submissions (CaregiversAssistanceClaim) to CARMA. It includes models that map to the Salesforce API interface and an http client.

## Design

### CARMA::Models
Used to hold model objects relating to CARMA's domain. More models can be added as the interface with CARMA grows (i.e. CARMA::Models::Case).

### CARMA::Client
This is an http client used to communicate with CARMA. It contains configuration and auth behavior needed to interface with the Salesforce app. This is an extension of our internal Salesforce service (lib/salesforce) which also extends Restforce (a ruby package for interfacing with the Salesforce API).

## Example

### Simple Submission
```
claim = CaregiversAssistanceClaim.new

submission = CARMA::Models::Submission.from_claim(claim)
submission.metadata = {
  veteran: {
    icn: '1234',
    is_veteran: true
  }
}

submission.submit!(CARMA::Client::Client.new)
```

### Submission with Attachments 
```
carma_client  = CARMA::Client::Client.new
claim         = SavedClaim::CaregiversAssistanceClaim.new
submission    = CARMA::Models::Submission.from_claim(
                  claim,
                  {
                    veteran: {
                      icn: '1234',
                      is_veteran: true
                    }
                  }
                )

submission.submit!(carma_client)

attachments = CARMA::Models::Attachments.new(
  submission.carma_case_id,
  claim.veteran_data['fullName']['first'],
  claim.veteran_data['fullName']['last']
)

attachments.add('10-10CG', 'tmp/pdfs/10-10CG-claim-guid.pdf')
attachments.add('POA', 'tmp/pdfs/POA-claim-guid.pdf')

attachments.submit!(carma_client)
```

## Data Contract
### Submission Request Body
```
{
  data: ref([10-10CG Data Schema](https://github.com/department-of-veterans-affairs/vets-json-schema/blob/master/dist/10-10CG-schema.json)) as json,
  metadata: {
    claimGuid: string;
    claimId: number | null;
    veteran: { icn: string | null; isVeteran?: true | false; },
    primaryCaregiver: { icn: string | null; isVeteran?: true | false; },
    secondaryCaregiverOne?: { icn: string | null; isVeteran?: true | false; },
    secondaryCaregiverTwo?: { icn: string | null; isVeteran?: true | false; },
  }
}
```
#### Additional Constraints
- If Veteran's status cannot be confirmed as true, icn must be sent as null.
