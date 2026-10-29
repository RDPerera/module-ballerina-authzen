# Change Log
This file contains all the notable changes done to the Ballerina AuthZEN package through the releases.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - Unreleased

### Fixed

- Shortened the first paragraph of the package README, so Ballerina Central shows the package summary.

## [1.0.0] - 2026-10-29

### Added

- Initial release of the `authzen` package, a Policy Enforcement Point (PEP) client for the [OpenID AuthZEN Authorization API 1.0](https://openid.net/specs/authorization-api-1_0.html).
- `Client`, with the operations:
  - `evaluate`: the Access Evaluation API.
  - `evaluateBatch`: the Access Evaluations API, with top-level defaults and the `execute_all`, `deny_on_first_deny` and `permit_on_first_permit` semantics.
  - `searchSubjects`, `searchResources` and `searchActions`: the Subject, Resource and Action Search APIs, with paging.
  - `getMetadata`: the PDP metadata, read from the well-known URL AuthZEN defines and rejected when it names another PDP.
- Endpoint discovery (`discoverEndpoints`): each request is sent to the endpoint the PDP advertises in its metadata.
- Authentication with any Ballerina HTTP client auth configuration (Bearer token, OAuth 2.0 grants, Basic auth, self-signed JWT), an API key in any header, or mutual TLS.
- The `X-Request-ID` request header (`RequestHeaders.requestId`).
