# vets-api endpoint removal/deprecation history
This document tracks removal and deprecation of API resources and other functionality in vets-api. 
Additive changes are easy to trace through commit history, but functionality that is removed may be hard to 
discover and trace in the future if developers don't know it existed in the first place. 

Include an entry in this file in the same pull request as that in which the API resource is removed or 
deprecated. That way the commit history of this file is tied to the commits in which changes were made. 

---
Template:
## Removed Resource Name
* Deprecation Date:
* Removal Date: 
* Rationale: 

---
## /v0/vic/{profile_photo_attachments,supporting_documentation_attachments}
* Removal Date: 5/2/2022
* Rationale: The vic/* endpoints were implemented as part of a proposed "VICv2" feature that was 
never launched to production. The associated frontend code is already moved, and Veteran ID Card (VIC)
functionality is implemented on a non-VA.gov site. 

## /v0/vso_appointments
* Removal Date: 4/28/2022
* Rationale: vso_appointments endpoint was built as part of a platform pilot in 2018, and never 
launched to production. Related models and service code in lib/vso_pdf was exclusive to this API and is 
also being removed. 

