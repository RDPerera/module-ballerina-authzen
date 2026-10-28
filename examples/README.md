# Ballerina AuthZEN Examples

This directory contains a set of examples to demonstrate how to use the `ballerina/authzen` library.

## Examples

- [**Check access in a todo app**](<todo-access-check/A sample todo access check using Ballerina AuthZEN.md>): check one access request with `evaluate`, then every user and action in one `evaluateBatch` call.
- [**Review who can access records**](<access-review/A sample access review using Ballerina AuthZEN.md>): find who may delete a record, which records a user may delete (page by page) and what a user may do on a record, with the Search APIs.

## Running the Examples

Each example is a self-contained Ballerina package. From inside an example's directory:

```shell
$ bal run
```

The examples are also built as part of the repository build (`./gradlew build` from the repository root), against the `ballerina/authzen` package from the same checkout.

Both examples run against a public PDP of the [AuthZEN interoperability tests](https://authzen-interop.net), which needs no credentials. To use another PDP, set `pdpUrl` in a `Config.toml` in the example directory.
