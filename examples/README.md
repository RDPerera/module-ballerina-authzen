# Examples

The `ballerina/authzen` package provides practical examples illustrating usage in various scenarios.

| Example | Description |
|---------|-------------|
| [`todo-access-check`](./todo-access-check) | Checks whether a user may perform an action with `evaluate`, then checks every user and action of a todo app in one `evaluateBatch` call |
| [`access-review`](./access-review) | Lists who may delete a record, the records a user may delete (page by page) and the actions a user may perform on a record, with the Search APIs |

## Prerequisites

1. Both examples run against a public PDP of the [AuthZEN interoperability tests](https://authzen-interop.net), so they need no credentials. To use another PDP, set `pdpUrl` in a `Config.toml` in the example directory.

2. Build and push the package to your local Ballerina repository:

    ```bash
    cd ../ballerina
    bal pack && bal push --repository=local
    ```

## Running an example

Execute the following commands to build an example from the source:

* To build an example:

    ```bash
    bal build
    ```

* To run an example:

    ```bash
    bal run
    ```

## Building the examples with the local module

**Warning**: Due to the absence of support for reading local repositories for single Ballerina files, the Bala of the module is manually written to the central repository as a workaround. Consequently, the bash script may modify your local Ballerina repositories.

Execute the following commands to build all the examples against the changes you have made to the module locally:

* To build all the examples:

    ```bash
    ./build.sh build
    ```

* To run all the examples:

    ```bash
    ./build.sh run
    ```
