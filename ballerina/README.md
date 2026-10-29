## Overview

[AuthZEN](https://openid.net/wg/authzen/) is the OpenID Foundation standard for asking a Policy Decision Point (PDP) for authorization decisions. The [Authorization API 1.0](https://openid.net/specs/authorization-api-1_0.html) defines how a Policy Enforcement Point (PEP) asks a PDP whether a subject may perform an action on a resource, without depending on how the PDP stores or evaluates its policies.

The WSO2 AuthZEN Connector lets your integration act as a PEP against any AuthZEN 1.0 PDP. Many authorization products implement AuthZEN, including Cerbos, Topaz, Open Policy Agent, OpenFGA, Axiomatics, PingAuthorize, SGNL and WSO2 Identity Server.

### Key features

- Ask whether a subject may perform an action on a resource, in a given context (`evaluate`).
- Ask many questions in one call, with shared defaults and the `execute_all`, `deny_on_first_deny` and `permit_on_first_permit` semantics (`evaluateBatch`).
- Find who may perform an action on a resource (`searchSubjects`), what a subject may access (`searchResources`) and what a subject may do (`searchActions`), page by page.
- Read the PDP metadata (`getMetadata`) from the well-known URL AuthZEN defines, including for PDPs served under a path, and reject metadata that names another PDP.
- Send each request to the endpoint the PDP advertises in its metadata (`discoverEndpoints`).
- Authenticate with a Bearer token, OAuth 2.0, Basic auth, a self-signed JWT, an API key or mutual TLS, or not at all.
- Correlate requests with the `X-Request-ID` header.

A denied access is not an error: the operation returns a decision of `false`. Operations return an error only when the PDP can't evaluate the request or can't be reached.

## Setup guide

To use the AuthZEN package, you need the URL of an AuthZEN 1.0 PDP and the credentials it expects, if any.

1. Get the PDP URL, which is its `policy_decision_point` identifier, for example `https://pdp.example.com` or, for a PDP that serves several tenants, `https://pdp.example.com/tenant1`. The package calls the AuthZEN endpoints under it, such as `https://pdp.example.com/access/v1/evaluation`.

2. Find out how the PDP authenticates its callers. AuthZEN recommends OAuth 2.0, and PDPs also use Bearer tokens, API keys and mutual TLS. Some PDPs, such as local development servers, don't authenticate their callers.

3. Optionally, check that the PDP publishes its metadata, which lists the APIs it supports:

    ```bash
    curl https://pdp.example.com/.well-known/authzen-configuration
    ```

To try the package without a PDP of your own, use one of the public PDPs of the [AuthZEN interoperability tests](https://authzen-interop.net), such as `https://authzen-proxy-demo.cerbos.dev`, which needs no credentials.

## Quickstart

To use the AuthZEN package in your Ballerina application, update the `.bal` file as follows:

### Step 1: Import the module

Import the `authzen` module.

```ballerina
import ballerina/authzen;
```

### Step 2: Instantiate a new client

Create an `authzen:Client` with the PDP URL and its credentials.

```ballerina
configurable string pdpUrl = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string tokenUrl = ?;

authzen:Client pdp = check new (pdpUrl,
    auth = {
        tokenUrl,
        clientId,
        clientSecret
    }
);
```

For a PDP that takes a Bearer token, set `auth = {token: accessToken}`. For an API key, set `auth = {apiKey: "<key>"}` to send it as the `Authorization` header, or add `headerName` to send it in another header.

### Step 3: Invoke the connector operation

Now, use the client to ask for decisions.

```ballerina
authzen:Decision result = check pdp->evaluate({
    subject: {'type: "user", id: "alice@example.com"},
    action: {name: "can_read"},
    'resource: {'type: "document", id: "123"}
});
if !result.decision {
    return error("Access denied");
}
```

### Step 4: Run the Ballerina application

```bash
bal run
```

## Examples

The `authzen` package provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerina-authzen/tree/main/examples), covering the following use cases:

1. [Todo access check](https://github.com/ballerina-platform/module-ballerina-authzen/tree/main/examples/todo-access-check) - Checks whether a user may perform an action, then checks every user and action of a todo app in one batch call.

2. [Access review](https://github.com/ballerina-platform/module-ballerina-authzen/tree/main/examples/access-review) - Lists who can delete a record, which records a user can delete (page by page), and what a user can do on a record.
