# 2. Use modules folder for claims evidence api code

Date: 2025-05-16

## Status

Accepted

## Context

The development cycle in vets-api is strained, with delays during review and an undesireable release cycle.  It was argued to contain the code for the Claims Evidence API in a separate repo and import to vets-api as another gem.  It was assumed that there would be more control and freedom over the development of the library, compared to if it were contained in the `modules` directory directly as part of vets-api.  There would have been an increased initial implmentation and integration cost, but later development would proceed much smoother.  This assumption was not correct.  There is still the same oversight for other repositories.  While the current CI process is not ideal it is predefined, and having the code within vets-api does allow reuse of existing libraries.

## Decision

The code for Claims Evidence API library will be placed in `modules`, which does contain a gemspec, so moving to a separate reporsitory later could be possible.

## Consequences

The development sprint cycle will be strained with the current process and delays may occur.
