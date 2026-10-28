# Todo access check

This example checks what the users of a shared todo app may do. It asks one question with `evaluate`, then asks for every user and action in one `evaluateBatch` call, which sends the shared resource once as a default and each user and action as a batch entry. The decisions come back in the order of the entries.

It runs against the public Cerbos PDP of the [AuthZEN interoperability tests](https://authzen-interop.net), which serves the interop "todo" scenario: Rick is an admin, Morty an editor and Beth a viewer.

## Prerequisites

- Ballerina Swan Lake 2201.12.x or later
- Push the package to the local repository:
  ```bash
  cd ../../ballerina
  bal pack && bal push --repository=local
  ```
- Optionally, to use another PDP that serves the interop "todo" scenario, create a `Config.toml` in this directory:
  ```toml
  pdpUrl = "https://<your-pdp>"
  ```

## Run the example

```bash
bal run
```

The example prints whether Beth may create a todo, then a permit or deny line for each user and action. Viewers may read todos but not create them.
