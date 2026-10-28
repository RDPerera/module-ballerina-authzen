# Review who can access records

## Overview

This example reviews who can do what with a company's records using the AuthZEN Search APIs. It lists the users who may delete a record (`searchSubjects`), the records a user may delete, two at a time until the PDP returns an empty page token (`searchResources`), and the actions the user may perform on one record (`searchActions`). The client reads the PDP metadata first (`discoverEndpoints`) and sends each search to the endpoint the PDP advertises.

It runs against the public Cerbos PDP of the [AuthZEN interoperability tests](https://authzen-interop.net), which serves the interop "search" scenario: users `alice` to `felix` and records `101` to `120`. The results depend on the policies of the PDP.

### Prerequisites

- Network access to the PDP. The public interop PDP needs no credentials.

### Configuration

The example uses the public interop PDP by default. To use another PDP that serves the interop "search" scenario, create a `Config.toml`:

```toml
pdpUrl = "https://<your-pdp>"
```

### Run

```shell
$ bal run
```

Until `ballerina/authzen` is published to Ballerina Central, run the example with the distribution that the repository build (`./gradlew build`) unpacks:

```shell
$ ../../target/ballerina-runtime/bin/bal run
```

The example prints the users who may delete record 102, the records bob may delete, and the actions bob may perform on record 102.
