# V2 Validation Field Mapping

This document maps validation fields in `revised_disability_compensation_validation.rb` to their corresponding locations in the v2 526.json schema and FES.pdf validation document.

## Field Validation Mapping Table

### Legend
- ✅ **Valid** = Field exists in v2 schema and is being validated
- ❌ **REMOVED** = Validation removed (field doesn't exist in v2 or has incompatible structure)
- ⚠️ **Warning** = Field exists but validation skipped or modified
- ~~Strikethrough~~ = Code/validation has been removed

### claimDate Fields
| Validation Field | V2 Schema Line | FES.pdf Section | Status |
|------------------|----------------|-----------------|--------|
| ~~`form_attributes['claimDate']`~~ | **NOT FOUND** | Section 2.1 | ❌ **REMOVED** - Field NOT in v2 schema |

### serviceInformation Fields
| Validation Field | V2 Schema Line | FES.pdf Section | Status |
|------------------|----------------|-----------------|--------|
| `form_attributes['serviceInformation']` | Line 734: `"serviceInformation": {` | Section 2.4 | ✅ Valid |
| `service_info['servicePeriods']` | Line 751: `"servicePeriods": {` | Section 2.4.b | ✅ Valid |
| `service_period['separationLocationCode']` | Line 787: `"separationLocationCode": {` | Section 2.4.a | ✅ Valid |
| `period['activeDutyBeginDate']` | Line 775: `"activeDutyBeginDate": {` | Section 2.4.b.ii | ✅ Valid |
| `period['activeDutyEndDate']` | Line 781: `"activeDutyEndDate": {` | Section 2.4.b.ii | ✅ Valid |

### reservesNationalGuardService Fields
| Validation Field | V2 Schema Line | FES.pdf Section | Status |
|------------------|----------------|-----------------|--------|
| `period['reservesNationalGuardService']` | Line 803: `"reservesNationalGuardService": {` | Section 2.4.c | ✅ Valid |
| `obligation_terms['beginDate']` | Line 820: `"beginDate": {`<br/>(under obligationTermsOfService) | Section 2.4.c.i | ✅ **IMPLEMENTED**<br/>Using v2 nested structure |
| `obligation_terms['endDate']` | Line 826: `"endDate": {`<br/>(under obligationTermsOfService) | Section 2.4.c.i | ✅ **IMPLEMENTED**<br/>Using v2 nested structure |
| ~~`rng_service['title10Activation']`~~ | **NOT FOUND** | Section 2.4.c.iii | ❌ **REMOVED**<br/>Field NOT in v2 schema |
| ~~`activation['title10ActivationDate']`~~ | **NOT FOUND** | Section 2.4.c.iv | ❌ **REMOVED**<br/>Field NOT in v2 schema |
| ~~`activation['anticipatedSeparationDate']`~~ | **NOT FOUND** | Section 2.4.c.iii | ❌ **REMOVED**<br/>Field NOT in v2 schema |

### federalActivation Fields
| Validation Field | V2 Schema Line | FES.pdf Section | Status |
|------------------|----------------|-----------------|--------|
| `service_info['federalActivation']` | Line 874: `"federalActivation": {` | Section 2.4 (top-level) | ✅ Valid |
| `federal_activation['activationDate']` | Line 880: `"activationDate": {` | Section 2.4 (top-level) | ✅ Valid |
| `federal_activation['anticipatedSeparationDate']` | Line 887: `"anticipatedSeparationDate": {` | Section 2.4 (top-level) | ✅ Valid |

### veteranIdentification.mailingAddress Fields
| Validation Field | V2 Schema Line | FES.pdf Section | Status |
|------------------|----------------|-----------------|--------|
| `form_attributes.dig('veteranIdentification', 'mailingAddress')` | Line 51: `"mailingAddress": {` | Section 5.b<br/>(currentMailingAddress in FES) | ✅ Valid |
| `mailing_address['country']` | Line 98: `"country": {` | Section 5.b.vi | ✅ Valid |
| `mailing_address['state']` | Line 91: `"state": {` | Section 5.b.ii.3<br/>**(RED text)** | ✅ Valid |
| `mailing_address['zipFirstFive']` | Line 104: `"zipFirstFive": {` | Section 5.b.ii.4<br/>**(RED text)** | ✅ Valid |
| `mailing_address['internationalPostalCode']` | Line 118: `"internationalPostalCode": {` | Section 5.b.v | ✅ Valid |

### changeOfAddress Fields
| Validation Field | V2 Schema Line | FES.pdf Section | Status |
|------------------|----------------|-----------------|--------|
| `form_attributes['changeOfAddress']` | Line 155: `"changeOfAddress": {` | Section 5.c | ✅ Valid |
| `change_of_address['typeOfAddressChange']` | Line 161: `"typeOfAddressChange": {` | Section 5.c | ✅ Valid<br/>(TEMPORARY/PERMANENT) |
| `change_of_address.dig('dates', 'beginDate')` | Line 235: `"beginDate": {`<br/>(under dates at line 232) | Section 5.c.i<br/>(beginningDate in FES) | ✅ Valid<br/>correct v2 structure |
| `change_of_address.dig('dates', 'endDate')` | Line 242: `"endDate": {`<br/>(under dates at line 232) | Section 5.c.i<br/>(endingDate in FES) | ✅ Valid<br/>correct v2 structure |
| `change_of_address['country']` | Line 205: `"country": {` | Section 5.c.ix | ✅ Valid |
| `change_of_address['state']` | Line 198: `"state": {` | Section 5.c.v.3<br/>**(RED text)** | ✅ Valid |
| `change_of_address['zipFirstFive']` | Line 211: `"zipFirstFive": {` | Section 5.c.v.4<br/>**(RED text)** | ✅ Valid |
| `change_of_address['internationalPostalCode']` | Line 225: `"internationalPostalCode": {` | Section 5.c.viii | ✅ Valid |

## Implementation Status

### ✅ Successfully REMOVED Fields (not in v2 schema):
1. **claimDate** - Section 2.1 of FES says "Not required and currently not used by VA.gov" 
2. **title10Activation** and all sub-fields:
   - `title10ActivationDate` 
   - `anticipatedSeparationDate` (for title10)
   - NOTE: These fields exist in FES v1 but NOT in v2 schema

### ✅ Successfully ADAPTED Fields (different structure in v2):
1. **ReservesNationalGuardService obligation dates**:
   - FES v1 expects: `obligationTermOfServiceFromDate` and `obligationTermOfServiceToDate`
   - v2 schema has: `obligationTermsOfService.beginDate` and `obligationTermsOfService.endDate`
   - **IMPLEMENTED**: Validation using v2 nested structure

### ✅ Currently VALIDATED Fields (exist in v2 and match FES requirements):
- All `veteranIdentification.mailingAddress.*` fields
  - `country`, `state`, `zipFirstFive`, `internationalPostalCode`
- All `changeOfAddress.*` fields with v2 structure
  - `typeOfAddressChange` (TEMPORARY/PERMANENT)
  - `dates.beginDate` and `dates.endDate`
  - `country`, `state`, `zipFirstFive`, `internationalPostalCode`
- All `serviceInformation.*` fields
  - `servicePeriods` with `activeDutyBeginDate`, `activeDutyEndDate`, `separationLocationCode`
  - `reservesNationalGuardService.obligationTermsOfService.beginDate/endDate` (v2 structure)
  - `federalActivation` with `activationDate`, `anticipatedSeparationDate`

## FES.pdf Document Format:
- ~~Strikethrough text~~ = Do NOT implement these validations
- **RED text** = NEW validations to implement
- Black text = Existing validations to keep (if field exists in v2)

## Key Differences Between FES v1 and v2 Schema:
- FES uses "currentMailingAddress" → v2 schema uses "mailingAddress"
- FES uses "beginningDate/endingDate" → v2 schema uses "dates.beginDate/dates.endDate"
- FES uses "addressChangeType" → v2 schema uses "typeOfAddressChange"
- FES expects flat obligation dates → v2 nests them under "obligationTermsOfService"