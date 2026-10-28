# Tests

The test suite covers the six operations of the AuthZEN package (`evaluate`, `evaluateBatch`, `searchSubjects`, `searchResources`, `searchActions` and `getMetadata`) against a mock PDP (`tests/mock_service.bal`) that implements the AuthZEN 1.0 HTTPS binding with a small policy.

It covers:

- Permit and deny decisions, with entity properties and context, and a deny returned as a decision rather than an error. `400` and `500` responses become `http:ClientRequestError` and `http:RemoteServerError`.
- Batch evaluation with top-level defaults that entries override, the `execute_all`, `deny_on_first_deny` and `permit_on_first_permit` semantics, and a batch without entries answered as a single decision.
- Subject, resource and action search, and paging with `page.limit`, `page.token` and `next_token`, which also checks that the snake_case JSON members map to the camelCase fields.
- The `X-Request-ID` header, which the mock PDP echoes.
- PDP metadata at the well-known URL of a PDP at a bare host and of a PDP under a path (`/.well-known/authzen-configuration/tenant1`), and metadata that names another PDP, which is rejected.
- Endpoint discovery: requests sent to the endpoints the PDP advertises, at the default paths and at custom URLs, operations whose endpoint the PDP doesn't advertise, and initialization that fails when the metadata is missing or names another PDP.
- Authentication with a Bearer token (checked by a mock PDP that returns `401` without it), OAuth 2.0 client credentials (with a mock token endpoint), Basic auth, and an API key in the `Authorization` header or a custom header.
- A search `page` without `next_token`, as in the AuthZEN example response (Figure 19).
- Credentials sent to a discovered custom endpoint, and advertised endpoints that are refused: a plain `http` endpoint of an `https` PDP, and a relative URL.
- The exact JSON the client sends for every operation (checked by a mock PDP that returns the request body), Unicode identifiers, members the PDP returns that AuthZEN doesn't define, a batch of 500 entries, and 100 concurrent calls on one client.
- PDP URL handling: rejected URLs (no scheme, another scheme, a query or a fragment), a trailing slash and an upper-case scheme, metadata URLs with ports, paths and IPv6 hosts, and the HTTP settings of the connection config.

## Running Tests

```bash
bal test
```

The test suite uses a mock PDP that runs on ports 9090 and 9091, so no PDP or credentials are required.

To also run the tests against a live PDP, set the following environment variables:

```bash
export IS_LIVE_SERVER=true
export AUTHZEN_PDP_URL=https://authzen-proxy-demo.cerbos.dev  # optional, this is the default
bal test --groups live_tests
```

The live tests call all six operations against a PDP of the [AuthZEN interoperability tests](https://authzen-interop.net) that serves the interop "todo" scenario on its evaluation APIs and the "search" scenario on its search APIs, such as the public Cerbos PDP. They only read decisions, and need no credentials.
