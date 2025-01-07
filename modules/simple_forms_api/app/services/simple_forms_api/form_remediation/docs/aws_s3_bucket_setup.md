# AWS S3 Bucket Setup

This guide provides step-by-step instructions for requesting, reviewing, and applying AWS S3 bucket configurations for your team. If your team does not have an S3 bucket, follow the instructions below.

---

## Table of Contents

- [AWS S3 Bucket Setup](#aws-s3-bucket-setup)
  - [Table of Contents](#table-of-contents)
  - [Requesting an S3 Bucket](#requesting-an-s3-bucket)
    - [Submitting a PR](#submitting-a-pr)
    - [Review Process](#review-process)
    - [Applying Changes](#applying-changes)
    - [Access and Credentials](#access-and-credentials)
      - [Production/Staging Environments](#productionstaging-environments)
      - [Local Development](#local-development)
      - [Additional Documentation](#additional-documentation)
  - [S3 Bucket Naming Convention](#s3-bucket-naming-convention)
  - [Future Infrastructure Requests](#future-infrastructure-requests)

---

## Requesting an S3 Bucket

### Submitting a PR

1. **Create a PR for Configuration**: Open a pull request to add the configuration for the new S3 bucket(s). Include both staging and production configurations in a single PR where possible.
2. **Follow Naming Conventions**: Use the standard naming conventions for each environment (see [S3 Bucket Naming Convention](#s3-bucket-naming-convention) below).
3. **Refer to Examples**: Review [Sample PR #1](https://github.com/department-of-veterans-affairs/devops/pull/14735) and [Sample PR #2](https://github.com/department-of-veterans-affairs/devops/pull/14742) as examples.

### Review Process

1. **Request Review**: After submitting the PR, the DevOps/Platform team (`vsp-operations`) review is automatically required because they are codeowners of the files in the `devops` repo.
2. **DevOps Review**: A Platform team member will perform an initial review of the PR for consistency and compliance.
3. **Sanity Check**: Ask for a **sanity check** to verify provisioning details, security settings, and overall configuration consistency.

### Applying Changes

1. **Merge and Apply**: Once the PR is approved and merged, the DevOps team will manually apply these changes in staging and production.
2. **Confirmation**: After provisioning, the DevOps team will confirm the creation and readiness of the bucket(s).

### Access and Credentials

#### Production/Staging Environments

- **Service Access**: The `vets-api` service account provides automatic access to S3 in production and staging through the **vets-api pod service account**.

#### Local Development

- **Developer Access**: Use your AWS credentials locally, either by setting environment variables or through AWS CLI configuration.
- **Testing**: Verify that the `vets-api` role can write to the S3 bucket in staging and production. Test access and permissions and report any issues that arise.

#### Additional Documentation

- Refer to internal documentation on using the `vets-api` role with AWS clients. Ensure that AWS credentials are properly configured for local development environments.

---

## S3 Bucket Naming Convention

When naming S3 buckets, follow these conventions to maintain consistency across environments:

- **Staging**: `dsva-vagov-staging-[team-project-name]`
- **Production**: `dsva-vagov-prod-[team-project-name]`

---

## Future Infrastructure Requests

For additional infrastructure needs:

1. **Use PRs for New Requests**: Submit requests via pull requests in the DevOps repository.
2. **Seek Assistance**: If unfamiliar with infrastructure management tools like Terraform, consult the Platform/DevOps team for support.
3. **Verify Permissions**: Always verify permissions in both staging and production environments to ensure proper access.
