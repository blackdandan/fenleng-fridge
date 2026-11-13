# Fenleng Flutter Firebase Identity

This optional package connects an authenticated Firebase user to the Fenleng
Shared Platform. It does not choose or embed provider-specific login UI:
configure Google, Facebook, Apple, email, OIDC/SAML, or other approved
providers in Firebase Authentication, then create a
`FirebaseIdentitySessionBridge` with the application's `FirebaseAuth`.

```dart
final bridge = FirebaseIdentitySessionBridge(
  auth: flutterAuthSdk,
  tokenSource: FirebaseAuthIdTokenSource(FirebaseAuth.instance),
);
await bridge.login(forceRefresh: true);
```

The Shared Platform must verify the Firebase ID token's signature, issuer,
audience and expiry before it links the user and creates a Fenleng session.
Never persist the Firebase ID token or treat Firebase's client callback as a
successful Fenleng login. WeChat and other Mainland China channel adapters stay
outside Firebase.
