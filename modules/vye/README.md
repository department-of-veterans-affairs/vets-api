# VYE Module

The Verify Your Enrollment (VYE) module is responsible for handling the logic and data-transfer associated with a veteran verifying their GI Bill benefits. In particular, every month the veteran is required to update how many education credits they took during the previous month. TODO: more detail here

While the `vets-api` is not necessarily the source of truth for a veterans enrollment status (that title belongs to BDN and now DGIB), it is the interface that va.gov uses to allow veterans to update their enrollment information. As such, you'll notice that a lot of the logic in VYE is about getting information from the veteran and then calling or syncing with other services to pass that information along.

## Primary Models

The VYE module consists of 8 principal models:

- `BdnClone`: BDN is the legacy system used to track veteran's enrollment information. To get information out of this system, a text file (`WAVE.txt`) is downloaded which contains all the relevant data. This text file is ingested and used to populate a bunch of database tables in the `vets-api` database. This process happens every evening, and a `BdnClone` represents one of these occurrences. At any given time there is only one `active` clone, and this is the where nearly all data for the API is read from. The `BdnClone` is the parent record for most all other records. So, the flow generally looks like:
  1. Create new `BdnClone`, it is not `active`
  2. Use latest `WAVE.txt` to create `UserInfo`, `AddressChange`, and `Award` records.
  3. Set the `BdnClone` to `active`, so that this clone is now used as the data source for all api calls.

- `UserProfile`: This represents a veteran in the BDN/DGIB system. There should only be one of these records per veteran, with uniqueness based on SSN or file number. It can be used as a consistent way to track/reference a veteran across `BdnClone`s.

- `UserInfo`: This represents the information for a single veteran pulled for a particular `BdnClone`. It includes things like `cert_issue_date`, `rpo_code`, and `fac_code`. It `belongs_to` a `BdnClone` and `has_many` `AddressChange`, `Award`, `DirectDepositChange`, and `Verification`

- `AddressChange`: Represents a veteran's request to change their address. It `belongs_to` a `UserInfo`.

- `Award`: Represents an award. TODO: more.

- `DirectDepositChange`: Represents a veteran's request to have their direct deposit information updated.

- `PendingDocument`: These come from TIMS (via a similar method to BDN where a txt/csv file is downloaded and then ingested). It `belongs_to` a `UserProfile`, and is not part of the `BdnClone` active/inactive stuff. TODO: example

- `Verification`: TODO: learn more here
