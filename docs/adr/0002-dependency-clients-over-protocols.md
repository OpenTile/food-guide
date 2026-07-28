# Dependencies are `@DependencyClient` structs, not protocols

The repo's standing instruction is to depend on protocols rather than concrete implementations,
but the iOS app is built on the Composable Architecture, whose grain is a struct of closures
declared with `@DependencyClient`. We follow the library instead of the standing rule: overriding
a single endpoint in a test is one line, and the macro generates a test value that fails loudly
on any unstubbed call — both of which a protocol seam gives up.

## Consequences

- This is a deliberate deviation, not an oversight. Converting these clients to protocols would
  fight `swift-dependencies` tooling and force every test stub to implement methods it never calls.
- The seam itself is unchanged: features depend on the client's interface, never on the live
  implementation, so the intent behind the standing rule is preserved.
